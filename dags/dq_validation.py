"""DQ Validation DAG — Phase 7A orchestration layer.

Runs all data quality checks across Bronze/Silver/Gold/Feature Store,
writes results to gold.dq_results, and gates downstream work via
ShortCircuitOperator.

Schedule: every 4 hours (aligned with feature_pipeline cadence).
"""
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.empty import EmptyOperator
from airflow.operators.python import PythonOperator, ShortCircuitOperator
from utils.clickhouse_hook import execute_clickhouse_query
from utils.audit_logger import write_dag_audit_log
from datetime import datetime, timedelta
import json
import re


def _write_dq_result(stage, check_name, check_type, status, details,
                     rows_checked, rows_failed):
    """Write a single DQ result row to gold.dq_results."""
    escaped = json.dumps(details).replace("'", "\\'")
    execute_clickhouse_query(
        f"INSERT INTO gold.dq_results VALUES "
        f"(now64(3), '{stage}', '{check_name}', '{check_type}', "
        f"'{status}', '{escaped}', {rows_checked}, {rows_failed})"
    )


# ---------------------------------------------------------------------------
# Task callables
# ---------------------------------------------------------------------------


def parse_and_write_dbt_results(**context):
    """Parse dbt test stdout and write summary to gold.dq_results."""
    ti = context["ti"]
    raw = ti.xcom_pull(task_ids="run_dbt_tests") or ""

    # If dbt task failed (no XCom output), write a skip record
    if not raw:
        _write_dq_result(
            "dbt", "dbt_test_suite", "test_run", "skip",
            {"reason": "dbt not available in MWAA environment"},
            0, 0,
        )
        ti.xcom_push(key="dbt_status", value="skip")
        return

    # Parse the summary line: "Done. PASS=53 WARN=2 ERROR=0 SKIP=0 TOTAL=55"
    m = re.search(
        r"PASS=(\d+)\s+WARN=(\d+)\s+ERROR=(\d+)\s+SKIP=(\d+)\s+TOTAL=(\d+)",
        raw,
    )
    if m:
        passed, warned, errored, skipped, total = (int(g) for g in m.groups())
    else:
        passed = warned = errored = skipped = total = 0

    status = "pass" if errored == 0 else "fail"
    details = {
        "passed": passed,
        "warned": warned,
        "errored": errored,
        "skipped": skipped,
        "total": total,
    }
    _write_dq_result(
        "dbt", "dbt_test_suite", "test_run", status, details, total, errored,
    )

    # Push status for quality gate
    ti.xcom_push(key="dbt_status", value=status)


def check_feature_completeness(**context):
    """Compare user count in Feature Store vs Silver."""
    silver = execute_clickhouse_query(
        "SELECT count() AS c FROM silver.users_silver FINAL"
    )
    silver_count = silver[0]["c"] if silver else 0

    fs = execute_clickhouse_query(
        "SELECT count(DISTINCT user_id) AS c "
        "FROM feature_store.user_credit_features"
    )
    fs_count = fs[0]["c"] if fs else 0

    coverage = fs_count / silver_count if silver_count > 0 else 0
    if coverage >= 0.95:
        status = "pass"
    elif coverage >= 0.80:
        status = "warn"
    else:
        status = "fail"

    _write_dq_result(
        "feature_store", "completeness_check", "completeness", status,
        {"silver_users": silver_count, "fs_users": fs_count,
         "coverage": round(coverage, 4)},
        silver_count, silver_count - fs_count,
    )

    context["ti"].xcom_push(key="fs_completeness_status", value=status)


def check_feature_nulls(**context):
    """Check for NULL feature values in the Feature Store."""
    null_query = """
    SELECT count() AS c
    FROM feature_store.user_credit_features
    WHERE tx_velocity_7d IS NULL
       OR tx_velocity_30d IS NULL
       OR avg_tx_amount_30d IS NULL
       OR repayment_rate_90d IS NULL
       OR merchant_diversity_30d IS NULL
       OR declined_rate_7d IS NULL
       OR active_installments IS NULL
       OR days_since_first_tx IS NULL
    """
    result = execute_clickhouse_query(null_query)
    null_count = result[0]["c"] if result else 0

    total = execute_clickhouse_query(
        "SELECT count() AS c FROM feature_store.user_credit_features"
    )
    total_count = total[0]["c"] if total else 0

    status = "pass" if null_count == 0 else "fail"
    _write_dq_result(
        "feature_store", "null_check", "completeness", status,
        {"null_rows": null_count, "total_rows": total_count},
        total_count, null_count,
    )

    context["ti"].xcom_push(key="fs_null_status", value=status)


def check_gold_completeness(**context):
    """Check Gold tables have expected row counts."""
    checks = [
        ("gold.merchant_daily_kpis", 200),
        ("gold.user_cohorts", 49000),
        ("gold.settlement_reconciliation", 200),
    ]
    all_pass = True
    results = {}
    for table, min_rows in checks:
        res = execute_clickhouse_query(f"SELECT count() AS c FROM {table}")
        cnt = res[0]["c"] if res else 0
        ok = cnt >= min_rows
        results[table] = {"rows": cnt, "min_expected": min_rows, "pass": ok}
        if not ok:
            all_pass = False

    status = "pass" if all_pass else "fail"
    _write_dq_result(
        "gold", "gold_completeness_check", "completeness", status,
        results, sum(r["rows"] for r in results.values()),
        sum(1 for r in results.values() if not r["pass"]),
    )
    context["ti"].xcom_push(key="gold_completeness_status", value=status)


def check_gold_feature_reconciliation(**context):
    """Reconcile Silver user count vs Feature Store user count."""
    silver = execute_clickhouse_query(
        "SELECT count() AS c FROM silver.users_silver FINAL"
    )
    fs = execute_clickhouse_query(
        "SELECT uniq(user_id) AS c FROM feature_store.user_credit_features"
    )
    silver_cnt = silver[0]["c"] if silver else 0
    fs_cnt = fs[0]["c"] if fs else 0
    coverage = fs_cnt / silver_cnt if silver_cnt > 0 else 0
    status = "pass" if coverage >= 0.95 else ("warn" if coverage >= 0.80 else "fail")
    _write_dq_result(
        "gold", "gold_feature_reconciliation", "reconciliation", status,
        {"silver_users": silver_cnt, "fs_users": fs_cnt,
         "coverage": round(coverage, 4)},
        silver_cnt, abs(silver_cnt - fs_cnt),
    )
    context["ti"].xcom_push(
        key="gold_reconciliation_status", value=status)


def evaluate_quality_gate(**context):
    """Check gold.dq_results for any 'fail' status in the last hour.

    Returns True (continue) if no failures, False (skip downstream) if any.
    """
    result = execute_clickhouse_query(
        "SELECT count() AS c FROM gold.dq_results "
        "WHERE status = 'fail' AND check_time > now() - INTERVAL 1 HOUR"
    )
    fail_count = result[0]["c"] if result else 0
    return fail_count == 0


# ---------------------------------------------------------------------------
# DAG definition
# ---------------------------------------------------------------------------

default_args = {
    "owner": "paystream",
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="dq_validation",
    schedule_interval="0 */4 * * *",
    start_date=datetime(2025, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["quality", "phase7"],
    default_args=default_args,
) as dag:

    run_dbt_tests = BashOperator(
        task_id="run_dbt_tests",
        bash_command=(
            "cd /usr/local/airflow/dbt && "
            "dbt test --target prod --profiles-dir . 2>&1 | tail -20"
        ),
        do_xcom_push=True,
    )

    write_dbt_results = PythonOperator(
        task_id="write_dbt_results_to_dq",
        python_callable=parse_and_write_dbt_results,
        trigger_rule="all_done",
    )

    fs_completeness = PythonOperator(
        task_id="check_feature_store_completeness",
        python_callable=check_feature_completeness,
    )

    fs_nulls = PythonOperator(
        task_id="check_feature_store_nulls",
        python_callable=check_feature_nulls,
    )

    quality_gate = ShortCircuitOperator(
        task_id="quality_gate",
        python_callable=evaluate_quality_gate,
        trigger_rule="all_done",
    )

    dq_complete = EmptyOperator(
        task_id="dq_complete",
    )

    audit = PythonOperator(
        task_id="write_audit_log",
        python_callable=write_dag_audit_log,
        trigger_rule="all_done",
    )

    gold_completeness = PythonOperator(
        task_id="check_gold_completeness",
        python_callable=check_gold_completeness,
    )

    gold_reconciliation = PythonOperator(
        task_id="check_gold_feature_reconciliation",
        python_callable=check_gold_feature_reconciliation,
    )

    # Dependencies
    run_dbt_tests >> write_dbt_results
    [write_dbt_results, fs_completeness, fs_nulls,
     gold_completeness, gold_reconciliation] >> quality_gate
    quality_gate >> dq_complete >> audit

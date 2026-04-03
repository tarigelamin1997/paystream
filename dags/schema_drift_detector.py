"""Schema Drift Detector DAG — Phase 7B.

Compares Avro schemas in Schema Registry against ClickHouse Bronze table
columns. Detects fields added to Avro (by Debezium schema evolution) that
don't yet exist in ClickHouse, indicating MV definitions need updating.

Schedule: every 6 hours.
"""
from airflow import DAG
from airflow.operators.python import PythonOperator
from utils.audit_logger import write_dag_audit_log
from datetime import datetime, timedelta
import json
import requests

SR_URL = "http://schema-registry.paystream.local:8081"

# Debezium topic-value subjects → ClickHouse Bronze tables
SUBJECT_TABLE_MAP = {
    "paystream.public.transactions-value": "bronze.pg_transactions_raw",
    "paystream.public.users-value": "bronze.pg_users_raw",
    "paystream.public.merchants-value": "bronze.pg_merchants_raw",
    "paystream.public.repayments-value": "bronze.pg_repayments_raw",
    "paystream.public.installment_schedules-value": "bronze.pg_installments_raw",
}

# Debezium envelope fields injected by ExtractNewRecordState SMT or Kafka Engine
# These appear in Avro but not as user-facing ClickHouse columns
IGNORED_AVRO_FIELDS = {"__op", "__source_ts_ms", "__deleted", "__table", "__lsn"}


def check_schema_drift(**context):
    """Compare Schema Registry Avro schemas against ClickHouse Bronze columns."""
    from utils.clickhouse_hook import execute_clickhouse_query

    drift_count = 0

    for subject, ch_table in SUBJECT_TABLE_MAP.items():
        db, table = ch_table.split(".")

        # Fetch latest Avro schema from Schema Registry
        try:
            sr_resp = requests.get(
                f"{SR_URL}/subjects/{subject}/versions/latest", timeout=10,
            )
            if sr_resp.status_code != 200:
                _write_drift_result(
                    ch_table, "skip",
                    {"reason": f"SR returned {sr_resp.status_code}", "subject": subject},
                    0, 0,
                )
                continue
            schema = json.loads(sr_resp.json()["schema"])
            avro_fields = {f["name"] for f in schema.get("fields", [])}
            avro_fields -= IGNORED_AVRO_FIELDS
        except Exception as e:
            _write_drift_result(
                ch_table, "skip",
                {"reason": f"SR unreachable: {e}", "subject": subject},
                0, 0,
            )
            continue

        # Fetch ClickHouse table columns
        rows = execute_clickhouse_query(
            f"SELECT name FROM system.columns "
            f"WHERE database = '{db}' AND table = '{table}'"
        )
        ch_columns = {r["name"] for r in rows}

        # Compare: Avro fields not in ClickHouse
        missing = avro_fields - ch_columns
        status = "pass" if not missing else "warn"
        if missing:
            drift_count += 1

        _write_drift_result(
            ch_table, status,
            {
                "subject": subject,
                "table": ch_table,
                "missing_columns": sorted(missing),
                "avro_field_count": len(avro_fields),
                "ch_column_count": len(ch_columns),
            },
            len(avro_fields), len(missing),
        )
        print(f"  {ch_table}: {status} "
              f"(avro={len(avro_fields)}, ch={len(ch_columns)}, missing={len(missing)})")

    print(f"Schema drift check complete: {drift_count} table(s) with drift")


def _write_drift_result(ch_table, status, details, rows_checked, rows_failed):
    """Write a schema drift result to gold.dq_results."""
    from utils.clickhouse_hook import execute_clickhouse_query

    table_short = ch_table.split(".")[-1]
    details_json = json.dumps(details).replace("'", "\\'")
    execute_clickhouse_query(
        f"INSERT INTO gold.dq_results VALUES "
        f"(now64(3), 'bronze', 'schema_drift_{table_short}', 'schema_drift', "
        f"'{status}', '{details_json}', {rows_checked}, {rows_failed})"
    )


default_args = {
    "owner": "paystream",
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="schema_drift_detector",
    schedule_interval="0 */6 * * *",
    start_date=datetime(2025, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["quality", "phase7", "schema"],
    default_args=default_args,
) as dag:

    drift_check = PythonOperator(
        task_id="check_schema_drift",
        python_callable=check_schema_drift,
    )

    audit = PythonOperator(
        task_id="write_audit_log",
        python_callable=write_dag_audit_log,
        trigger_rule="all_done",
    )

    drift_check >> audit

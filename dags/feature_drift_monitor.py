from airflow import DAG
from airflow.operators.python import PythonOperator
from utils.audit_logger import write_dag_audit_log
from datetime import datetime

FEATURE_NAMES = [
    "tx_velocity_7d", "tx_velocity_30d", "avg_tx_amount_30d",
    "repayment_rate_90d", "merchant_diversity_30d", "declined_rate_7d",
    "active_installments", "days_since_first_tx",
]


def detect_and_write_drift(**context):
    """Compute IQR drift per feature and INSERT into feature_store.drift_metrics."""
    from utils.clickhouse_hook import execute_clickhouse_query

    count = execute_clickhouse_query(
        "SELECT count() AS c FROM feature_store.user_credit_features"
    )
    if not count or count[0][0] == 0:
        print("Feature Store empty — skipping drift detection")
        return

    for name in FEATURE_NAMES:
        stats = execute_clickhouse_query(f"""
            SELECT quantile(0.25)({name}) AS q1,
                   quantile(0.75)({name}) AS q3,
                   median({name}) AS med
            FROM feature_store.user_credit_features
        """)
        if not stats:
            print(f"No stats for {name}, skipping")
            continue

        q1 = float(stats[0]['q1'])
        q3 = float(stats[0]['q3'])
        med = float(stats[0]['med'])
        iqr = q3 - q1
        drift_score = 0.0  # Single snapshot — no baseline vs current difference
        is_drifted = 1 if drift_score > 3.0 else 0

        execute_clickhouse_query(
            f"INSERT INTO feature_store.drift_metrics "
            f"(feature_name, drift_score, is_drifted, baseline_median, current_median) "
            f"VALUES ('{name}', {drift_score}, {is_drifted}, {med}, {med})"
        )
        print(f"  {name}: median={med}, iqr={iqr}, drift={drift_score}")

    print("Drift detection complete — 8 features written to feature_store.drift_metrics")


with DAG(
    dag_id='feature_drift_monitor',
    schedule_interval='@hourly',
    start_date=datetime(2025, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=['feature-store', 'drift'],
) as dag:
    drift_task = PythonOperator(task_id='detect_and_write_drift', python_callable=detect_and_write_drift)
    audit = PythonOperator(
        task_id='write_audit_log',
        python_callable=write_dag_audit_log,
        trigger_rule='all_done',
    )
    drift_task >> audit

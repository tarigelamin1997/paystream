from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from utils.clickhouse_hook import execute_clickhouse_query
from utils.audit_logger import write_dag_audit_log
from datetime import datetime

def run_ge_validation(**context):
    """Quality gate on Silver data. Fails DAG if checks fail."""
    ch_result = execute_clickhouse_query(
        "SELECT count() FROM silver.transactions_silver WHERE amount < 0"
    )
    if ch_result[0][0] > 0:
        raise ValueError(f"GE FAIL: {ch_result[0][0]} negative amounts in Silver")
    ch_result = execute_clickhouse_query(
        "SELECT count() FROM silver.repayments_silver FINAL WHERE status NOT IN ('pending','paid','overdue','waived')"
    )
    if ch_result[0][0] > 0:
        raise ValueError(f"GE FAIL: {ch_result[0][0]} invalid repayment statuses")

def verify_feature_store(**context):
    """Confirm Feature Store has rows."""
    count = execute_clickhouse_query(
        "SELECT count() AS c FROM feature_store.user_credit_features"
    )
    if not count or count[0][0] == 0:
        raise ValueError("Feature Store empty")

with DAG(
    dag_id='feature_pipeline',
    schedule_interval='0 */4 * * *',
    start_date=datetime(2025, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=['feature-store'],
) as dag:
    ge_gate = PythonOperator(
        task_id='ge_validation', python_callable=run_ge_validation,
    )
    # Phase 4 Discovery: EMR Serverless JDBC blocked by DateTime64 overflow.
    # Feature computation uses HTTP-based compute_features.py (no clickhouse-driver).
    compute = BashOperator(
        task_id='compute_features',
        bash_command='python3 /usr/local/airflow/dags/utils/compute_features.py',
    )
    verify_fs = PythonOperator(
        task_id='verify_feature_store', python_callable=verify_feature_store,
    )
    audit = PythonOperator(
        task_id='write_audit_log',
        python_callable=write_dag_audit_log,
        trigger_rule='all_done',
    )
    ge_gate >> compute >> verify_fs >> audit

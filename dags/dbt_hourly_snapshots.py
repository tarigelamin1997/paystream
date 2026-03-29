from airflow import DAG
from airflow.operators.python import ShortCircuitOperator
from airflow.operators.bash import BashOperator
from utils.clickhouse_hook import execute_clickhouse_query
from datetime import datetime

def check_new_data(**context):
    prev = context['prev_execution_date_success'] or datetime(2000, 1, 1)
    m_count = execute_clickhouse_query(
        f"SELECT count() FROM silver.merchants_silver WHERE _ingested_at > '{prev}'"
    )[0][0]
    u_count = execute_clickhouse_query(
        f"SELECT count() FROM silver.users_silver WHERE _ingested_at > '{prev}'"
    )[0][0]
    return (m_count + u_count) > 0

with DAG(
    dag_id='dbt_hourly_snapshots',
    schedule_interval='@hourly',
    start_date=datetime(2025, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=['dbt', 'snapshot'],
) as dag:
    check = ShortCircuitOperator(
        task_id='check_new_data',
        python_callable=check_new_data,
    )
    snapshot = BashOperator(
        task_id='dbt_snapshot',
        bash_command='cd /usr/local/airflow/dbt && dbt snapshot --target prod --profiles-dir .',
    )
    check >> snapshot

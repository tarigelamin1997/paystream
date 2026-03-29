from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from utils.clickhouse_hook import execute_clickhouse_query
from datetime import datetime
import json

def write_test_results_to_clickhouse(**context):
    """Parse dbt test JSON output and INSERT into gold.dbt_test_results."""
    ti = context['ti']
    test_output = ti.xcom_pull(task_ids='dbt_test')
    results = json.loads(test_output) if test_output else []
    for r in results:
        execute_clickhouse_query(f"""
            INSERT INTO gold.dbt_test_results
            (test_name, status, execution_time, tested_at)
            VALUES ('{r["name"]}', '{r["status"]}', {r["execution_time"]}, now())
        """)

with DAG(
    dag_id='data_quality_gate',
    schedule_interval='0 4 * * *',
    start_date=datetime(2025, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=['quality', 'daily'],
) as dag:
    freshness = BashOperator(
        task_id='dbt_source_freshness',
        bash_command='cd /usr/local/airflow/dbt && dbt source freshness --target prod --profiles-dir . --output json',
    )
    test = BashOperator(
        task_id='dbt_test',
        bash_command='cd /usr/local/airflow/dbt && dbt test --target prod --profiles-dir . --output json',
        do_xcom_push=True,
    )
    write_results = PythonOperator(
        task_id='write_test_results',
        python_callable=write_test_results_to_clickhouse,
    )
    freshness >> test >> write_results

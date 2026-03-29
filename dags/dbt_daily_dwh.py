from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from datetime import datetime

with DAG(
    dag_id='dbt_daily_dwh',
    schedule_interval='0 3 * * *',
    start_date=datetime(2025, 1, 1),
    catchup=True,
    max_active_runs=1,
    tags=['dbt', 'daily'],
) as dag:
    dbt_build = BashOperator(
        task_id='dbt_build',
        bash_command='cd /usr/local/airflow/dbt && dbt build --target prod --profiles-dir .',
    )
    trigger_features = TriggerDagRunOperator(
        task_id='trigger_feature_pipeline',
        trigger_dag_id='feature_pipeline',
        wait_for_completion=False,
    )
    dbt_build >> trigger_features

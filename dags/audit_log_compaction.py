from airflow import DAG
from airflow.operators.python import PythonOperator
from utils.audit_logger import write_dag_audit_log
from datetime import datetime, timedelta
import boto3

def cleanup_old_audit_files(**context):
    """Remove S3 Parquet/CSV audit files older than 7 days.
    Phase 4 writes Parquet/CSV (not Delta Lake — Spark JDBC blocked by
    DateTime64 overflow). This DAG manages the S3 audit trail lifecycle.
    If Delta Lake is re-enabled in future, replace with OPTIMIZE + VACUUM."""
    s3 = boto3.client('s3')
    bucket = 'paystream-features-dev'
    prefix = 'user_credit/'
    cutoff = datetime.utcnow() - timedelta(days=7)

    response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
    for obj in response.get('Contents', []):
        if obj['LastModified'].replace(tzinfo=None) < cutoff:
            s3.delete_object(Bucket=bucket, Key=obj['Key'])
            print(f"Deleted: {obj['Key']}")

with DAG(
    dag_id='audit_log_compaction',
    schedule_interval='0 2 * * *',
    start_date=datetime(2025, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=['s3', 'maintenance'],
) as dag:
    cleanup = PythonOperator(
        task_id='cleanup_old_audit_files',
        python_callable=cleanup_old_audit_files,
    )
    audit = PythonOperator(
        task_id='write_audit_log',
        python_callable=write_dag_audit_log,
        trigger_rule='all_done',
    )
    cleanup >> audit

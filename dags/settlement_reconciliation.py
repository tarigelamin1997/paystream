from airflow import DAG
from airflow.operators.python import PythonOperator
from utils.clickhouse_hook import execute_clickhouse_query
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

def compute_settlements(**context):
    """Query yesterday's approved transaction totals per merchant."""
    yesterday = (context['execution_date'] - timedelta(days=1)).strftime('%Y-%m-%d')
    results = execute_clickhouse_query(f"""
        SELECT
            merchant_id,
            sum(amount) AS expected_amount,
            count()     AS tx_count
        FROM silver.transactions_silver
        WHERE status = 'approved'
          AND toDate(created_at) = '{yesterday}'
        GROUP BY merchant_id
    """)
    context['ti'].xcom_push(key='settlements', value=results)

def reconcile_and_insert(**context):
    """Compare expected vs actual settlements, INSERT into Gold, alert on variance."""
    settlements = context['ti'].xcom_pull(key='settlements', task_ids='compute_settlements')
    for row in settlements:
        merchant_id = row['merchant_id']
        expected = row['expected_amount']
        # In production: actual_amount comes from bank settlement file
        # For portfolio: simulate actual = expected * (1 + small random variance)
        actual = expected  # placeholder — actual settlement integration out of scope
        variance = abs(expected - actual)
        variance_pct = (variance / expected * 100) if expected > 0 else 0
        status = 'matched' if variance_pct <= 0.1 else 'mismatch'

        execute_clickhouse_query(f"""
            INSERT INTO gold.settlement_reconciliation
            (settlement_date, merchant_id, expected_amount, actual_amount,
             variance, variance_pct, status)
            VALUES (
                '{context['execution_date'].strftime('%Y-%m-%d')}',
                {merchant_id}, {expected}, {actual},
                {variance}, {variance_pct}, '{status}'
            )
        """)

        if status == 'mismatch':
            logger.warning(
                f"SETTLEMENT MISMATCH: merchant={merchant_id} "
                f"expected={expected} actual={actual} variance={variance_pct}%"
            )

with DAG(
    dag_id='settlement_reconciliation',
    schedule_interval='0 6 * * *',
    start_date=datetime(2025, 1, 1),
    catchup=False,
    max_active_runs=1,
    sla_miss_callback=None,  # Phase 6 configures CloudWatch alarm on SLA breach
    tags=['finance', 'settlement'],
) as dag:
    compute = PythonOperator(
        task_id='compute_settlements',
        python_callable=compute_settlements,
        sla=timedelta(hours=1),
    )
    reconcile = PythonOperator(
        task_id='reconcile_and_insert',
        python_callable=reconcile_and_insert,
    )
    compute >> reconcile

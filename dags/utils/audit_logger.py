"""Pipeline audit logger — writes DAG run events to gold.pipeline_audit_log.

Uses the same ClickHouse HTTP hook as all other DAGs.
Audit logging is non-fatal: failures are logged but never break the pipeline.
"""
import json
from utils.clickhouse_hook import execute_clickhouse_query


def log_pipeline_event(dag_id, task_id, run_id, status,
                       duration_seconds=0, details=None):
    """Write a single audit row to gold.pipeline_audit_log."""
    details_json = json.dumps(details) if details else "{}"
    details_json = details_json.replace("'", "\\'")
    try:
        execute_clickhouse_query(
            f"INSERT INTO gold.pipeline_audit_log "
            f"(event_time, dag_id, task_id, run_id, status, "
            f"duration_seconds, details) VALUES "
            f"(now64(3), '{dag_id}', '{task_id}', '{run_id}', "
            f"'{status}', {duration_seconds}, '{details_json}')"
        )
    except Exception as e:
        print(f"Audit log write failed (non-fatal): {e}")


def write_dag_audit_log(**context):
    """Airflow PythonOperator callable — logs DAG run completion."""
    dag_id = context["dag"].dag_id
    run_id = context["run_id"]
    dag_run = context["dag_run"]
    state = dag_run.get_state()
    status = "success" if state == "success" else "failed"

    log_pipeline_event(
        dag_id=dag_id,
        task_id="audit_log",
        run_id=run_id,
        status=status,
        details={"state": state, "external_trigger": dag_run.external_trigger},
    )

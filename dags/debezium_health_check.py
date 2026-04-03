"""Debezium Health Check DAG — Phase 7C.

Monitors both Debezium connectors (PG + Mongo) via REST API.
Auto-restarts failed tasks. Logs results to gold.pipeline_audit_log
and gold.dq_results on failure.

Schedule: every 5 minutes.
"""
from airflow import DAG
from airflow.operators.python import PythonOperator
from utils.clickhouse_hook import execute_clickhouse_query
from utils.audit_logger import write_dag_audit_log, log_pipeline_event
from datetime import datetime, timedelta
import json
import requests
import boto3

ECS_CLUSTER = "paystream-ecs"
REGION = "eu-north-1"

CONNECTORS = {
    "pg": {
        "service": "paystream-debezium-pg",
        "connector_name": "paystream-pg-connector",
    },
    "mongo": {
        "service": "paystream-debezium-mongo",
        "connector_name": "paystream-mongo-connector",
    },
}


def _get_task_ip(service_name):
    """Discover ECS task private IP for a Debezium service."""
    ecs = boto3.client("ecs", region_name=REGION)
    tasks = ecs.list_tasks(
        cluster=ECS_CLUSTER, serviceName=service_name,
    ).get("taskArns", [])
    if not tasks:
        return None
    detail = ecs.describe_tasks(cluster=ECS_CLUSTER, tasks=[tasks[0]])
    for task in detail.get("tasks", []):
        for att in task.get("attachments", []):
            for d in att.get("details", []):
                if d["name"] == "privateIPv4Address":
                    return d["value"]
    return None


def _write_dq_fail(connector_type, details):
    """Write a fail row to gold.dq_results for alerting."""
    details_json = json.dumps(details).replace("'", "\\'")
    execute_clickhouse_query(
        f"INSERT INTO gold.dq_results VALUES "
        f"(now64(3), 'debezium', 'connector_{connector_type}_health', "
        f"'health_check', 'fail', '{details_json}', 1, 1)"
    )


def check_debezium(connector_type, **context):
    """Check connector status, restart if failed, write audit."""
    cfg = CONNECTORS[connector_type]
    run_id = context["run_id"]

    try:
        ip = _get_task_ip(cfg["service"])
    except Exception as e:
        # IAM permission denied or other ECS API error — log and skip
        print(f"  {connector_type}: ECS discovery failed: {e}")
        log_pipeline_event(
            dag_id="debezium_health_check",
            task_id=f"check_{connector_type}",
            run_id=run_id,
            status="skip",
            details={"reason": f"ECS API error: {type(e).__name__}"},
        )
        return

    if not ip:
        log_pipeline_event(
            dag_id="debezium_health_check",
            task_id=f"check_{connector_type}",
            run_id=run_id,
            status="error",
            details={"reason": f"ECS task not found for {cfg['service']}"},
        )
        _write_dq_fail(connector_type, {"reason": "ECS task not found"})
        return

    base_url = f"http://{ip}:8083"
    connector_name = cfg["connector_name"]

    try:
        resp = requests.get(
            f"{base_url}/connectors/{connector_name}/status", timeout=10,
        )
        if resp.status_code != 200:
            log_pipeline_event(
                dag_id="debezium_health_check",
                task_id=f"check_{connector_type}",
                run_id=run_id,
                status="error",
                details={"reason": f"REST API returned {resp.status_code}"},
            )
            _write_dq_fail(connector_type, {"reason": f"HTTP {resp.status_code}"})
            return

        status = resp.json()
        conn_state = status["connector"]["state"]
        task_states = [t["state"] for t in status.get("tasks", [])]

        if conn_state == "RUNNING" and all(s == "RUNNING" for s in task_states):
            print(f"  {connector_type}: HEALTHY (connector={conn_state}, tasks={task_states})")
            log_pipeline_event(
                dag_id="debezium_health_check",
                task_id=f"check_{connector_type}",
                run_id=run_id,
                status="success",
                details={"connector": conn_state, "tasks": task_states},
            )
            return

        # Restart failed tasks
        restarted = []
        for i, task in enumerate(status.get("tasks", [])):
            if task["state"] == "FAILED":
                print(f"  {connector_type}: Restarting task {i} (was FAILED)")
                requests.post(
                    f"{base_url}/connectors/{connector_name}/tasks/{i}/restart",
                    timeout=10,
                )
                restarted.append(i)

        log_pipeline_event(
            dag_id="debezium_health_check",
            task_id=f"check_{connector_type}",
            run_id=run_id,
            status="restarted" if restarted else "degraded",
            details={
                "connector": conn_state,
                "tasks": task_states,
                "restarted_tasks": restarted,
            },
        )

        if not restarted and conn_state != "RUNNING":
            _write_dq_fail(connector_type, {
                "connector": conn_state, "tasks": task_states,
            })

    except Exception as e:
        print(f"  {connector_type}: ERROR - {e}")
        log_pipeline_event(
            dag_id="debezium_health_check",
            task_id=f"check_{connector_type}",
            run_id=run_id,
            status="error",
            details={"error": str(e)},
        )
        _write_dq_fail(connector_type, {"error": str(e)})


default_args = {
    "owner": "paystream",
    "depends_on_past": False,
    "retries": 0,
    "retry_delay": timedelta(minutes=1),
}

with DAG(
    dag_id="debezium_health_check",
    schedule_interval="*/5 * * * *",
    start_date=datetime(2025, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["debezium", "health", "phase7"],
    default_args=default_args,
) as dag:

    check_pg = PythonOperator(
        task_id="check_debezium_pg",
        python_callable=check_debezium,
        op_kwargs={"connector_type": "pg"},
    )

    check_mongo = PythonOperator(
        task_id="check_debezium_mongo",
        python_callable=check_debezium,
        op_kwargs={"connector_type": "mongo"},
    )

    audit = PythonOperator(
        task_id="write_audit_log",
        python_callable=write_dag_audit_log,
        trigger_rule="all_done",
    )

    [check_pg, check_mongo] >> audit

#!/bin/bash
set -euo pipefail
REGION="${AWS_REGION:-eu-north-1}"
APPLICATION_ID="${EMR_APP_ID:-00g4gf50q62nb51d}"
EXECUTION_ROLE="${EMR_ROLE_ARN}"
CLICKHOUSE_HOST="${CLICKHOUSE_HOST:-10.0.10.70}"

echo "=== Submitting EMR Serverless Feature Engineering Job ==="

JOB_RUN_ID=$(aws emr-serverless start-job-run \
    --application-id "$APPLICATION_ID" \
    --execution-role-arn "$EXECUTION_ROLE" \
    --name "paystream-feature-engineering" \
    --job-driver "{
        \"sparkSubmit\": {
            \"entryPoint\": \"s3://paystream-delta-dev/spark-jobs/credit_feature_engineer.py\",
            \"entryPointArguments\": [\"--snapshot-ts\", \"auto\", \"--clickhouse-host\", \"${CLICKHOUSE_HOST}\", \"--delta-path\", \"s3://paystream-features-dev/user_credit/\"],
            \"sparkSubmitParameters\": \"--jars s3://paystream-delta-dev/spark-jars/clickhouse-jdbc-0.6.0-all.jar --packages io.delta:delta-spark_2.12:3.2.0 --conf spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog\"
        }
    }" \
    --configuration-overrides "{
        \"monitoringConfiguration\": {
            \"s3MonitoringConfiguration\": {
                \"logUri\": \"s3://paystream-delta-dev/spark-logs/\"
            }
        }
    }" \
    --region "$REGION" \
    --query 'jobRunId' --output text)

echo "Job submitted: $JOB_RUN_ID"
echo "$JOB_RUN_ID" > /tmp/emr_job_id.txt

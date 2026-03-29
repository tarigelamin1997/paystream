#!/bin/bash
set -euo pipefail
REGION="${AWS_REGION:-eu-north-1}"
APPLICATION_ID="${EMR_APP_ID:-00g4gf50q62nb51d}"
JOB_RUN_ID="${1:-$(cat /tmp/emr_job_id.txt)}"

echo "Polling job $JOB_RUN_ID..."
for i in $(seq 1 60); do
    STATUS=$(aws emr-serverless get-job-run \
        --application-id "$APPLICATION_ID" \
        --job-run-id "$JOB_RUN_ID" \
        --region "$REGION" \
        --query 'jobRun.state' --output text)
    echo "  [$i] Status: $STATUS"
    case "$STATUS" in
        SUCCESS) echo "Job completed successfully."; exit 0 ;;
        FAILED|CANCELLED) echo "Job $STATUS."; exit 1 ;;
    esac
    sleep 15
done
echo "Timeout waiting for job."
exit 1

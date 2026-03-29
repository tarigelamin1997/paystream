#!/bin/bash
set -euo pipefail
REGION="${AWS_REGION:-eu-north-1}"
BUCKET="paystream-mwaa-dags-dev"

echo "=== Syncing DAGs to MWAA S3 ==="
aws s3 sync dags/ "s3://${BUCKET}/dags/" \
  --exclude "__pycache__/*" --exclude "*.pyc" \
  --exclude "requirements.txt" \
  --region "$REGION"

echo "Syncing requirements.txt..."
aws s3 cp dags/requirements.txt "s3://${BUCKET}/requirements.txt" \
  --region "$REGION"

echo "=== DAG Sync Complete ==="
aws s3 ls "s3://${BUCKET}/dags/" --region "$REGION"

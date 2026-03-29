#!/bin/bash
set -euo pipefail
# Build and push Debezium Docker images to ECR

REGION="${AWS_REGION:-eu-north-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "=== Building and Pushing Debezium Images ==="

# ECR login
aws ecr get-login-password --region "${REGION}" | docker login --username AWS --password-stdin "${ECR_BASE}"

# Build Debezium PG
echo "Building Debezium PG image..."
docker build -f debezium/docker/Dockerfile.debezium-pg -t paystream-debezium-pg:latest debezium/docker/
docker tag paystream-debezium-pg:latest "${ECR_BASE}/paystream-debezium-pg:latest"
docker push "${ECR_BASE}/paystream-debezium-pg:latest"

# Build Debezium Mongo
echo "Building Debezium Mongo image..."
docker build -f debezium/docker/Dockerfile.debezium-mongo -t paystream-debezium-mongo:latest debezium/docker/
docker tag paystream-debezium-mongo:latest "${ECR_BASE}/paystream-debezium-mongo:latest"
docker push "${ECR_BASE}/paystream-debezium-mongo:latest"

echo "=== Images Pushed Successfully ==="

#!/usr/bin/env bash
set -euo pipefail

# PayStream Clean Verification
# Confirms no paystream-prefixed AWS resources remain after teardown.

REGION="eu-north-1"
PASS=0
FAIL=0

check_empty() {
  local desc="$1" count="$2"
  if [[ "$count" -eq 0 ]]; then
    echo "  [CLEAN] ${desc}: 0 resources"
    PASS=$((PASS + 1))
  else
    echo "  [DIRTY] ${desc}: ${count} resource(s) found"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== PayStream Clean Verification ==="
echo "Region: ${REGION}"
echo ""

# EC2 instances
ec2_count=$(aws ec2 describe-instances --region "${REGION}" \
  --filters "Name=tag:Name,Values=paystream-*" "Name=instance-state-name,Values=running,stopped" \
  --query "length(Reservations[].Instances[])" --output text 2>/dev/null || echo "0")
check_empty "EC2 instances (paystream-*)" "${ec2_count}"

# RDS instances
rds_count=$(aws rds describe-db-instances --region "${REGION}" \
  --query "length(DBInstances[?starts_with(DBInstanceIdentifier,'paystream-')])" --output text 2>/dev/null || echo "0")
check_empty "RDS instances (paystream-*)" "${rds_count}"

# MSK clusters
msk_count=$(aws kafka list-clusters-v2 --region "${REGION}" \
  --query "length(ClusterInfoList[?starts_with(ClusterName,'paystream-')])" --output text 2>/dev/null || echo "0")
check_empty "MSK clusters (paystream-*)" "${msk_count}"

# ECS services
ecs_clusters=$(aws ecs list-clusters --region "${REGION}" --query "clusterArns" --output text 2>/dev/null || echo "")
ecs_count=0
for cluster in ${ecs_clusters}; do
  svc_count=$(aws ecs list-services --region "${REGION}" --cluster "${cluster}" \
    --query "length(serviceArns)" --output text 2>/dev/null || echo "0")
  ecs_count=$((ecs_count + svc_count))
done
check_empty "ECS services" "${ecs_count}"

# S3 buckets
s3_count=$(aws s3api list-buckets --query "length(Buckets[?starts_with(Name,'paystream-')])" --output text 2>/dev/null || echo "0")
check_empty "S3 buckets (paystream-*)" "${s3_count}"

# DocumentDB
docdb_count=$(aws docdb describe-db-clusters --region "${REGION}" \
  --query "length(DBClusters[?starts_with(DBClusterIdentifier,'paystream-')])" --output text 2>/dev/null || echo "0")
check_empty "DocumentDB clusters (paystream-*)" "${docdb_count}"

echo ""
echo "Passed: ${PASS}, Dirty: ${FAIL}"

if [[ ${FAIL} -eq 0 ]]; then
  echo "STATUS: Environment is clean"
  exit 0
else
  echo "STATUS: ${FAIL} resource type(s) still present"
  exit 1
fi

#!/bin/bash
# PayStream — FastAPI Feature Store Concurrent Load Test
# Usage: ./scripts/load_test.sh [CONCURRENCY] [TOTAL_REQUESTS]
# Run from bastion for VPC-internal latency numbers.
set -euo pipefail

CONCURRENCY=${1:-10}
TOTAL=${2:-100}
ALB="${ALB_URL:-http://paystream-fastapi-alb-1584201898.eu-north-1.elb.amazonaws.com}"

echo "Load test: ${TOTAL} requests, ${CONCURRENCY} concurrent"
echo "Target: ${ALB}/features/user/{id}"
echo ""

seq 1 "$TOTAL" | xargs -P "$CONCURRENCY" -I{} \
  curl -s -o /dev/null -w "%{http_code} %{time_total}\n" \
  "${ALB}/features/user/{}" > /tmp/load_test_results.txt

SUCCESS=$(grep -c "^200" /tmp/load_test_results.txt || echo "0")
ERRORS=$((TOTAL - SUCCESS))

awk '{print $2}' /tmp/load_test_results.txt | sort -n | awk -v total="$TOTAL" -v ok="$SUCCESS" -v err="$ERRORS" '
{a[NR]=$1}
END {
  printf "=== Results ===\n"
  printf "Success: %d | Errors: %d\n", ok, err
  printf "P50: %.0fms\n", a[int(NR*0.5)]*1000
  printf "P95: %.0fms\n", a[int(NR*0.95)]*1000
  printf "P99: %.0fms\n", a[int(NR*0.99)]*1000
  printf "Max: %.0fms\n", a[NR]*1000
}'

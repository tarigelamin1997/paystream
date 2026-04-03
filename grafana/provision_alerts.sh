#!/bin/bash
set -euo pipefail
# Provision Grafana alert rules via API
GF="http://localhost:3000"
AUTH="admin:paystream"
DS="PDEE91DDB90597936"

create_rule() {
  local title="$1" sql="$2" threshold_type="$3" threshold_val="$4" duration="$5" severity="$6" summary="$7" time_range="$8"
  local payload=$(python3 -c "
import json, sys
print(json.dumps({
  'title': sys.argv[1],
  'ruleGroup': 'paystream-alerts',
  'folderUID': 'paystream',
  'orgID': 1,
  'condition': 'C',
  'for': sys.argv[5],
  'noDataState': 'OK',
  'execErrState': 'OK',
  'labels': {'severity': sys.argv[6], 'team': 'paystream'},
  'annotations': {'summary': sys.argv[7]},
  'data': [
    {'refId':'A','datasourceUid':sys.argv[8],'relativeTimeRange':{'from':int(sys.argv[9]),'to':0},'model':{'rawSql':sys.argv[2],'format':'table'}},
    {'refId':'B','datasourceUid':'__expr__','relativeTimeRange':{'from':0,'to':0},'model':{'type':'reduce','expression':'A','reducer':'last','settings':{'mode':'dropNN'}}},
    {'refId':'C','datasourceUid':'__expr__','relativeTimeRange':{'from':0,'to':0},'model':{'type':'threshold','expression':'B','conditions':[{'evaluator':{'type':sys.argv[3],'params':[float(sys.argv[4])]}}]}}
  ]
}))
" "$title" "$sql" "$threshold_type" "$threshold_val" "$duration" "$severity" "$summary" "$DS" "$time_range")

  result=$(curl -s -o /dev/null -w "%{http_code}" -u "$AUTH" -X POST "$GF/api/v1/provisioning/alert-rules" -H "Content-Type: application/json" -d "$payload")
  if [ "$result" = "201" ]; then
    echo "  OK: $title"
  else
    echo "  FAIL ($result): $title"
    curl -s -u "$AUTH" -X POST "$GF/api/v1/provisioning/alert-rules" -H "Content-Type: application/json" -d "$payload"
    echo
  fi
}

echo "=== Provisioning Grafana Alert Rules ==="

create_rule "Pipeline DAG Failed" \
  "SELECT count() AS c FROM gold.pipeline_audit_log WHERE status = 'failed' AND event_time > now() - INTERVAL 1 HOUR" \
  "gt" "0" "0s" "critical" "A pipeline DAG run has failed" "3600"

create_rule "Ingestion Flatline (No Bronze Rows 5 min)" \
  "SELECT count() AS recent FROM bronze.pg_transactions_raw WHERE _ingested_at >= now() - INTERVAL 5 MINUTE" \
  "lt" "1" "5m" "critical" "No new rows ingested into Bronze for 5 minutes" "600"

create_rule "Approval Rate Drop (> 15%)" \
  "SELECT countIf(status='approved') * 100.0 / count() AS rate FROM silver.transactions_silver WHERE created_at >= now() - INTERVAL 1 HOUR" \
  "lt" "50" "5m" "warning" "Transaction approval rate dropped significantly" "3600"

create_rule "Feature Pipeline Stale (> 6 hours)" \
  "SELECT dateDiff('hour', max(_ingested_at), now()) AS hours_stale FROM feature_store.user_credit_features" \
  "gt" "6" "0s" "warning" "Feature Store not updated in over 6 hours" "21600"

create_rule "Feature Drift Detected" \
  "SELECT count() AS drifted FROM feature_store.drift_metrics WHERE is_drifted = 1 AND measured_at > now() - INTERVAL 1 HOUR" \
  "gt" "0" "0s" "warning" "Feature drift score exceeds threshold" "3600"

create_rule "Settlement Reconciliation Mismatch" \
  "SELECT count() AS mismatches FROM gold.settlement_reconciliation WHERE status = 'mismatch' AND settlement_date >= today() - 1" \
  "gt" "0" "0s" "warning" "Settlement variance exceeds threshold" "86400"

create_rule "Bronze Ingestion Lag (> 60 min)" \
  "SELECT dateDiff('minute', max(_ingested_at), now()) AS lag_min FROM bronze.pg_transactions_raw" \
  "gt" "60" "5m" "warning" "No new data ingested for over 60 minutes" "7200"

echo ""
echo "=== Verifying ==="
curl -s -u "$AUTH" "$GF/api/v1/provisioning/alert-rules" | python3 -c "
import json, sys
rules = json.load(sys.stdin)
print(f'{len(rules)} alert rules:')
for r in rules:
    print(f'  - {r[\"title\"]}')
"

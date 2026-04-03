#!/bin/bash
set -euo pipefail
# Fix all Grafana alert rules to use ClickHouse plugin v4.14.0 query format
# Adds queryType=sql, rawQuery=true, format=1 to make queries evaluate correctly
GF="http://localhost:3000"
AUTH="admin:paystream"
DS="PDEE91DDB90597936"

update_rule() {
  local uid="$1" title="$2" sql="$3" threshold_type="$4" threshold_val="$5" duration="$6" severity="$7" summary="$8" time_range="$9"
  local payload=$(python3 -c "
import json, sys
print(json.dumps({
  'uid': sys.argv[1],
  'title': sys.argv[2],
  'ruleGroup': 'paystream-alerts',
  'folderUID': 'paystream',
  'orgID': 1,
  'condition': 'C',
  'for': sys.argv[6],
  'noDataState': 'OK',
  'execErrState': 'OK',
  'labels': {'severity': sys.argv[7], 'team': 'paystream'},
  'annotations': {'summary': sys.argv[8]},
  'data': [
    {'refId':'A','datasourceUid':sys.argv[9],'relativeTimeRange':{'from':int(sys.argv[10]),'to':0},'queryType':'sql','model':{'rawSql':sys.argv[3],'format':1,'queryType':'sql','rawQuery':True,'meta':{'builderOptions':{'mode':'list'}}}},
    {'refId':'B','datasourceUid':'__expr__','relativeTimeRange':{'from':0,'to':0},'model':{'type':'reduce','expression':'A','reducer':'last','settings':{'mode':'dropNN'}}},
    {'refId':'C','datasourceUid':'__expr__','relativeTimeRange':{'from':0,'to':0},'model':{'type':'threshold','expression':'B','conditions':[{'evaluator':{'type':sys.argv[4],'params':[float(sys.argv[5])]}}]}}
  ]
}))
" "$uid" "$title" "$sql" "$threshold_type" "$threshold_val" "$duration" "$severity" "$summary" "$DS" "$time_range")

  result=$(curl -s -o /dev/null -w "%{http_code}" -u "$AUTH" -X PUT "$GF/api/v1/provisioning/alert-rules/$uid" -H "Content-Type: application/json" -d "$payload")
  echo "  $title -> HTTP $result"
}

echo "=== Fixing Grafana Alert Rules (ClickHouse plugin format) ==="

# Get UIDs
UIDS=$(curl -s -u "$AUTH" "$GF/api/v1/provisioning/alert-rules" | python3 -c "
import json, sys
rules = json.load(sys.stdin)
for r in rules:
    print(f'{r[\"uid\"]} {r[\"title\"]}')
")
echo "$UIDS"
echo "---"

# Get individual UIDs
UID_PIPELINE=$(echo "$UIDS" | grep "Pipeline DAG" | awk '{print $1}')
UID_INGESTION=$(echo "$UIDS" | grep "Ingestion Flatline" | awk '{print $1}')
UID_APPROVAL=$(echo "$UIDS" | grep "Approval Rate" | awk '{print $1}')
UID_FEATURE=$(echo "$UIDS" | grep "Feature Pipeline" | awk '{print $1}')
UID_DRIFT=$(echo "$UIDS" | grep "Feature Drift" | awk '{print $1}')
UID_SETTLEMENT=$(echo "$UIDS" | grep "Settlement" | awk '{print $1}')
UID_LAG=$(echo "$UIDS" | grep "Bronze Ingestion" | awk '{print $1}')

update_rule "$UID_PIPELINE" "Pipeline DAG Failed" \
  "SELECT count() AS c FROM gold.pipeline_audit_log WHERE status = 'failed' AND event_time > now() - INTERVAL 1 HOUR" \
  "gt" "0" "0s" "critical" "A pipeline DAG run has failed" "3600"

update_rule "$UID_INGESTION" "Ingestion Flatline (No Bronze Rows 5 min)" \
  "SELECT count() AS recent FROM bronze.pg_transactions_raw WHERE _ingested_at >= now() - INTERVAL 5 MINUTE" \
  "lt" "1" "5m" "critical" "No new rows ingested into Bronze for 5 minutes" "600"

update_rule "$UID_APPROVAL" "Approval Rate Drop (> 15%)" \
  "SELECT countIf(status='approved') * 100.0 / count() AS rate FROM silver.transactions_silver WHERE created_at >= now() - INTERVAL 1 HOUR" \
  "lt" "50" "5m" "warning" "Transaction approval rate dropped significantly" "3600"

update_rule "$UID_FEATURE" "Feature Pipeline Stale (> 6 hours)" \
  "SELECT dateDiff('hour', max(_ingested_at), now()) AS hours_stale FROM feature_store.user_credit_features" \
  "gt" "6" "0s" "warning" "Feature Store not updated in over 6 hours" "21600"

update_rule "$UID_DRIFT" "Feature Drift Detected" \
  "SELECT count() AS drifted FROM feature_store.drift_metrics WHERE is_drifted = 1 AND measured_at > now() - INTERVAL 1 HOUR" \
  "gt" "0" "0s" "warning" "Feature drift score exceeds threshold" "3600"

update_rule "$UID_SETTLEMENT" "Settlement Reconciliation Mismatch" \
  "SELECT count() AS mismatches FROM gold.settlement_reconciliation WHERE status = 'mismatch' AND settlement_date >= today() - 1" \
  "gt" "0" "0s" "warning" "Settlement variance exceeds threshold" "86400"

update_rule "$UID_LAG" "Bronze Ingestion Lag (> 60 min)" \
  "SELECT dateDiff('minute', max(_ingested_at), now()) AS lag_min FROM bronze.pg_transactions_raw" \
  "gt" "60" "5m" "warning" "No new data ingested for over 60 minutes" "7200"

echo "=== Done ==="

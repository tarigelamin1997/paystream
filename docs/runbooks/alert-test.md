# PayStream — End-to-End Alerting Test

## Purpose
Verify the complete alerting chain: failure → Grafana detection → Lambda bridge → SNS → email notification.

## Prerequisites
- All infrastructure running (ClickHouse, Grafana, MWAA, FastAPI)
- SNS email subscription confirmed
- Lambda + API Gateway deployed (`terraform output grafana_webhook_url`)
- Grafana alert rules active (8 rules in PayStream Alerts folder)

## Test Procedure

### Test 1: Lambda Bridge (direct)
```bash
WEBHOOK_URL=$(cd terraform && terraform output -raw grafana_webhook_url)
curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"title":"E2E Test","state":"alerting","alerts":[{"status":"firing","labels":{"alertname":"e2e_test","severity":"info"},"annotations":{"summary":"Lambda bridge test"}}]}'
```
**Expected:** Email received within 1 minute with subject `[PayStream] E2E Test`.

### Test 2: Grafana → Lambda → SNS → Email
Write a test 'fail' row to trigger the "DQ Check Failed" Grafana alert:
```bash
ssh -i ~/.ssh/paystream-bastion.pem ec2-user@<BASTION_IP> \
  "curl -s 'http://10.0.10.70:8123/' --data-binary \"INSERT INTO gold.dq_results VALUES (now64(3), 'test', 'e2e_alert_test', 'e2e', 'fail', '{\\\"test\\\": true}', 1, 1)\""
```
Wait 1-2 minutes for Grafana alert evaluation.
**Expected:** Email received with DQ check failed alert.

**Cleanup:**
```bash
ssh -i ~/.ssh/paystream-bastion.pem ec2-user@<BASTION_IP> \
  "curl -s 'http://10.0.10.70:8123/' --data-binary \"ALTER TABLE gold.dq_results DELETE WHERE check_name = 'e2e_alert_test'\""
```

### Test 3: Circuit Breaker
```bash
# Normal request (circuit closed)
curl -s http://paystream-fastapi-alb-*.eu-north-1.elb.amazonaws.com/features/user/12345

# Check circuit breaker metric
curl -s http://paystream-fastapi-alb-*.eu-north-1.elb.amazonaws.com/metrics | grep circuit_breaker
# Expected: paystream_circuit_breaker_trips_total 0.0
```

### Test 4: Debezium Health Check (if MWAA has ECS IAM)
Trigger debezium_health_check DAG and verify audit log shows connector status.

## Results Log

| Test | Date | Result | Notes |
|---|---|---|---|
| 1: Lambda direct | | | |
| 2: Grafana chain | | | |
| 3: Circuit breaker | | | |
| 4: Debezium health | | | |

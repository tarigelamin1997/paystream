#!/bin/bash
# Chaos Scenario 4: Debezium Connector Failure (Self-Healing)
# Restarts the PG connector task, verifies it recovers.
set -euo pipefail

BASTION_EIP="${BASTION_EIP:-56.228.74.219}"
SSH_KEY="${SSH_KEY:-~/.ssh/paystream-bastion.pem}"
REGION="eu-north-1"
PROFILE="orderflow"

echo "=== Chaos: Debezium Task Restart ==="

echo "[1/4] Discovering Debezium PG task IP..."
TASK_ARN=$(aws ecs list-tasks --cluster paystream-ecs --service-name paystream-debezium-pg \
  --region $REGION --profile $PROFILE --query 'taskArns[0]' --output text)
DEBEZIUM_IP=$(aws ecs describe-tasks --cluster paystream-ecs --tasks "$TASK_ARN" \
  --region $REGION --profile $PROFILE \
  --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value' --output text)
echo "  IP: $DEBEZIUM_IP"

echo "[2/4] Baseline status..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@"$BASTION_EIP" \
  "curl -s http://${DEBEZIUM_IP}:8083/connectors/paystream-pg-connector/status | python3 -c \"
import json,sys
d=json.load(sys.stdin)
print(f'  Connector: {d[\"connector\"][\"state\"]}')
for t in d.get('tasks',[]): print(f'  Task {t[\"id\"]}: {t[\"state\"]}')
\"" 2>/dev/null

echo "[3/4] Restarting task 0..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@"$BASTION_EIP" \
  "curl -s -X POST http://${DEBEZIUM_IP}:8083/connectors/paystream-pg-connector/tasks/0/restart" 2>/dev/null
echo "  Restart sent. Waiting 15s..."
sleep 15

echo "[4/4] Post-restart status..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@"$BASTION_EIP" \
  "curl -s http://${DEBEZIUM_IP}:8083/connectors/paystream-pg-connector/status | python3 -c \"
import json,sys
d=json.load(sys.stdin)
state=d['connector']['state']
tasks=[t['state'] for t in d.get('tasks',[])]
print(f'  Connector: {state}, Tasks: {tasks}')
if state == 'RUNNING' and all(t == 'RUNNING' for t in tasks):
    print('=== Scenario 4: PASS ===')
else:
    print('=== Scenario 4: FAIL ===')
\"" 2>/dev/null

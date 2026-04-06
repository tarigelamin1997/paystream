# Infrastructure Resume Runbook

How to restart PayStream after stopping EC2 instances to save costs.

## Prerequisites

- AWS CLI configured with `orderflow` profile
- SSH key: `~/.ssh/paystream-bastion.pem`
- Region: `eu-north-1`

## Steps

### 1. Start EC2 Instances

```bash
INSTANCE_IDS=$(aws ec2 describe-instances --region eu-north-1 --profile orderflow \
  --filters "Name=tag:Project,Values=paystream" "Name=instance-state-name,Values=stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text)

aws ec2 start-instances --instance-ids $INSTANCE_IDS --region eu-north-1 --profile orderflow
aws ec2 wait instance-running --instance-ids $INSTANCE_IDS --region eu-north-1 --profile orderflow
```

### 2. Check RDS

RDS auto-restarts after 7 days per AWS policy. Check status:

```bash
aws rds describe-db-instances --db-instance-identifier paystream-rds \
  --region eu-north-1 --profile orderflow \
  --query 'DBInstances[0].DBInstanceStatus' --output text
```

If `stopped`, start it:
```bash
aws rds start-db-instance --db-instance-identifier paystream-rds --region eu-north-1 --profile orderflow
```

### 3. Check ECS Services

```bash
for svc in paystream-schema-registry paystream-debezium-pg paystream-debezium-mongo paystream-fastapi; do
  echo -n "$svc: "
  aws ecs describe-services --cluster paystream-ecs --services $svc \
    --region eu-north-1 --profile orderflow \
    --query 'services[0].runningCount' --output text
done
```

If any show `0`, scale up:
```bash
aws ecs update-service --cluster paystream-ecs --service <name> --desired-count 1 \
  --region eu-north-1 --profile orderflow
```

### 4. Run Post-Restart Recovery

```bash
make post-restart
```

If `make post-restart` fails (requires SSH tunnels), verify manually:

```bash
BASTION_EIP=$(terraform -chdir=terraform output -raw bastion_eip)
CH_IP=$(terraform -chdir=terraform output -raw clickhouse_private_ip)

# ClickHouse
ssh -i ~/.ssh/paystream-bastion.pem ec2-user@$BASTION_EIP \
  "curl -s http://${CH_IP}:8123/?query=SELECT+version()"

# Grafana
ssh -i ~/.ssh/paystream-bastion.pem ec2-user@$BASTION_EIP \
  "curl -s -u admin:paystream http://${CH_IP}:3000/api/health"

# FastAPI
curl -s http://paystream-fastapi-alb-1584201898.eu-north-1.elb.amazonaws.com/health
```

### 5. Check Debezium Connector

If the Debezium PG connector is in FAILED state after restart, the `debezium_health_check` DAG (every 5 min) will auto-restart it. Check audit log:

```bash
ssh -i ~/.ssh/paystream-bastion.pem ec2-user@$BASTION_EIP \
  "curl -s http://${CH_IP}:8123/ --data-binary 'SELECT dag_id, status, max(event_time) FROM gold.pipeline_audit_log WHERE dag_id=\"debezium_health_check\" GROUP BY dag_id, status ORDER BY status'"
```

## Known Issues

- **Schema Registry** may crash-loop after stop/start. See [schema-registry-recovery.md](schema-registry-recovery.md).
- **RDS storage-full** blocks stop command. Expand storage first: `aws rds modify-db-instance --allocated-storage 100 --apply-immediately`.

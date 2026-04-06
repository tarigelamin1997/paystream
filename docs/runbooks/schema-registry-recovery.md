# Schema Registry Recovery Runbook

## Symptoms

- Schema Registry ECS service shows `Running: 0, Desired: 1`
- `schema_drift_detector` DAG logs `status=skip` with "SR unreachable"
- CloudWatch logs show `EssentialContainerExited`

## Diagnosis

Check CloudWatch logs for the latest stopped task:

```bash
MSYS_NO_PATHCONV=1 aws logs describe-log-streams \
  --log-group-name "/ecs/paystream/schema-registry" \
  --region eu-north-1 --profile orderflow \
  --order-by LastEventTime --descending --max-items 1 --output json

# Get the logStreamName, then:
MSYS_NO_PATHCONV=1 aws logs get-log-events \
  --log-group-name "/ecs/paystream/schema-registry" \
  --log-stream-name "<stream-name>" \
  --region eu-north-1 --profile orderflow --limit 50
```

## Common Root Causes

### 1. TopicAuthorizationException

Schema Registry uses IAM auth to MSK. The `_schemas` internal topic requires these IAM actions:
- `kafka-cluster:DescribeTopicDynamicConfiguration`
- `kafka-cluster:AlterTopicDynamicConfiguration`
- `kafka-cluster:DescribeClusterDynamicConfiguration`

**Fix:** Update the `paystream-msk-iam-auth` IAM policy to include the missing actions.

### 2. Timed out waiting for join group

The `schema-registry` consumer group is stuck in a rebalance loop (common after multiple crash-loop restarts). Default init timeout is 60s, which is too short.

**Fix:** Add to ECS task definition environment:
```
SCHEMA_REGISTRY_KAFKASTORE_INIT_TIMEOUT_MS=120000
```

### 3. Replication factor mismatch

Default `_schemas` topic replication factor is 3, but PayStream MSK has 2 brokers.

**Fix:** Add to ECS task definition environment:
```
SCHEMA_REGISTRY_KAFKASTORE_TOPIC_REPLICATION_FACTOR=2
```

## Recovery Steps

1. Check logs to identify the specific error
2. If IAM: update policy via `aws iam create-policy-version`
3. If config: register new ECS task definition with corrected env vars
4. Update ECS service: `aws ecs update-service --force-new-deployment --task-definition <new-revision>`
5. Wait 2 minutes, verify `Running: 1`
6. Test connectivity: `curl http://schema-registry.paystream.local:8081/subjects` from ClickHouse EC2

## Incident History

- **2026-04-06:** Crash-loop after EC2 stop/start cycle. Root cause: IAM policy missing `DescribeTopicDynamicConfiguration` + RF=3 mismatch + 60s init timeout. Fixed with IAM policy v4 + task def v6.

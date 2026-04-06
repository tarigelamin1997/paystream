# PayStream Incident Log

All incidents documented using the Five Questions framework.

---

## INC-001: Year-2299 Timestamp Cascade (2026-04-03 to 2026-04-04)

**Severity:** CRITICAL | **Duration:** ~12 hours (discovery to verified fix)

### What happened?
All 500,001 transaction timestamps in `silver.transactions_silver` showed year 2299. This cascaded to: `repayment_rate_90d = 0` for all users, `days_since_first_tx = 0` (ShortType overflow), and broken temporal queries.

### Why?
Debezium PostgreSQL connector sends `TIMESTAMP` columns as **microseconds** (adaptive mode default). Bronze MVs used `fromUnixTimestamp64Milli` (expects milliseconds). Factor-1000 mismatch pushed all dates to year 2299.

### How did we discover it?
QA audit (Phase 7 verification) found the data corruption. Initial score: 52/100.

### Fix applied
- Changed 5 Bronze MVs: `fromUnixTimestamp64Milli` to `toDateTime64(fromUnixTimestamp64Micro(...), 3)`
- Corrected existing data via EXCHANGE TABLE
- Fixed `ShortType()` to `IntegerType()` in Spark feature engineer
- Fixed `toUInt16` to `toUInt32` in MWAA compute_features.py
- Added far-future timestamp cap as safety guard
- Added Bronze timestamp range check to `dq_validation` DAG (post-chaos gap fix)

### Prevention
Bronze timestamp range DQ check now detects `toYear(created_at) > toYear(now()) + 1`. Runs every 4 hours as part of the quality gate.

**Commit:** `0b2a66e`

---

## INC-002: Schema Registry ECS Crash-Loop (2026-04-05 to 2026-04-06)

**Severity:** MEDIUM | **Duration:** ~18 hours

### What happened?
Schema Registry ECS service: `Running: 0, Desired: 1`. Container crash-looping with `EssentialContainerExited`. The `schema_drift_detector` DAG logged `status=skip` for all checks.

### Why?
Two compounding root causes:
1. IAM policy `paystream-msk-iam-auth` lacked `DescribeTopicDynamicConfiguration` and `AlterTopicDynamicConfiguration` actions. Schema Registry couldn't validate the `_schemas` topic configuration.
2. Default `replicationFactor=3` mismatched our 2-broker MSK cluster.
3. Default 60s init timeout too short after crash-loop rebalance storm.

### How did we discover it?
Chaos testing (Gap 2) revealed Schema Registry was unreachable. Initial investigation guessed "MSK connectivity." Deeper CloudWatch log analysis found the actual `TopicAuthorizationException`.

### Fix applied
- IAM policy v4: added `DescribeClusterDynamicConfiguration`, `DescribeTopicDynamicConfiguration`, `AlterTopicDynamicConfiguration`
- ECS task definition v6: added `SCHEMA_REGISTRY_KAFKASTORE_TOPIC_REPLICATION_FACTOR=2`
- ECS task definition v6: added `SCHEMA_REGISTRY_KAFKASTORE_INIT_TIMEOUT_MS=120000`

### Prevention
Validate IAM policy against full MSK API requirements at provision time. Set RF to match actual broker count in Terraform variables.

**Runbook:** [schema-registry-recovery.md](runbooks/schema-registry-recovery.md)

---

## INC-003: Grafana Alert Rules Error State (2026-04-03)

**Severity:** LOW | **Duration:** ~2 hours

### What happened?
All 8 Grafana alert rules evaluated with `Normal (Error)` state instead of `Normal` or `Alerting`.

### Why?
ClickHouse Grafana plugin v4.14.0 requires specific query model fields: `queryType: "sql"`, `rawQuery: true`, `format: 1`. Without these, the plugin silently fails to execute the SQL query.

### How did we discover it?
Phase 7 Task 10 E2E alerting test. Initial investigation assumed network issue between ClickHouse EC2 and API Gateway. curl test from EC2 proved connectivity was fine (14ms RTT). Root cause was query format.

### Fix applied
Updated all 8 alert rules via `PUT /api/v1/provisioning/alert-rules/{uid}` with corrected query model.

### Prevention
All new Grafana dashboard panels and alert rules must include `queryType: "sql"`, `rawQuery: true`, `format: 1` in their target definition.

**Commit:** `d5ab43d`

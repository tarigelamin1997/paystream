# PayStream -- Real-Time BNPL Data Platform & Feature Store

[Demo Video](https://youtube.com/watch?v=PLACEHOLDER)

A production-grade, real-time data platform for Buy Now Pay Later (BNPL) operations. PayStream ingests transactional and behavioural data via CDC, transforms it through Bronze/Silver/Gold layers in ClickHouse, computes credit risk features, and serves them via a sub-50ms REST API.

Built entirely on AWS managed services. Deployed and torn down with a single command.

---

## Architecture

```
  RDS PostgreSQL 15          DocumentDB 6.0
        |                          |
   Debezium PG (ECS)        Debezium Mongo (ECS)
        |                          |
        +--- MSK Provisioned ------+
             (Kafka 3.6)
                  |
        Schema Registry (ECS)
                  |
          ClickHouse 24.8 (EC2)
          +-------+-------+
          |       |       |
        Bronze  Silver   Gold
          |               |
          |          dbt 1.8.0
          |               |
          +--- Feature Store ---+
               |                |
         Delta Lake 3.2    ClickHouse
          (S3 audit)       (serving)
                                |
                          FastAPI (ECS)
                           + ALB
                                |
                          Consumers
```

**Orchestration:** MWAA (Airflow 2.10) -- 10 DAGs managing dbt, feature computation, drift detection, data quality, and health checks.

**Observability:** Self-hosted Grafana OSS on ClickHouse EC2 (port 3000) -- 6 dashboards, 8 alert rules, Lambda + API Gateway SNS bridge for email alerting.

**QA Score:** 91/100 (journey: 52 -> 75 -> 83 -> 91). See [QA Audit Report](docs/qa-audit-report.md).

---

## Tech Stack

| Component | Service | Version |
|---|---|---|
| Transactional DB | RDS PostgreSQL | 15 |
| Behavioural DB | Amazon DocumentDB | 5.0 |
| Streaming | MSK Provisioned | Kafka 3.6.0 |
| CDC | Debezium on ECS Fargate | 2.7.0 |
| Schema Registry | Confluent on ECS Fargate | 7.6.1 |
| OLAP Warehouse | ClickHouse on EC2 (r6i.large) | 24.8 |
| Batch Compute | EMR Serverless (Spark) | 3.5.1 |
| Table Format | Delta Lake on S3 | 3.2.0 |
| Transformations | dbt-core + dbt-clickhouse | 1.8.0 |
| Feature API | FastAPI on ECS Fargate + ALB | 0.111.0 |
| Orchestration | MWAA (Airflow) | 2.10.0 |
| Monitoring | Self-hosted Grafana OSS + ClickHouse drift_metrics | 11.0.0 |
| Alerting | Lambda SNS bridge + API Gateway + CloudWatch | -- |
| IaC | Terraform | 1.7.5 |
| Language | Python | 3.12 |

All versions are declared in `versions.yaml` at the repo root.

---

## Region and Deployment

- **Region:** `eu-north-1` (Stockholm)
- **AZ:** Single -- `eu-north-1a` (with `eu-north-1b` private subnet for MWAA only)
- **Access:** All services in private subnets. SSH tunnel through bastion host.
- **Cost:** ~$5.80 per 6-hour session. Tear down with `make teardown` when done.

---

## Quick Start

### Prerequisites

- AWS CLI configured with credentials for `eu-north-1`
- Terraform >= 1.7.5
- Docker (for Debezium image builds)
- Python 3.12+
- SSH key pair for bastion access (`~/.ssh/paystream-bastion.pem`)

### Deploy the Platform

```bash
# 1. Validate prerequisites
make preflight

# 2. Deploy all infrastructure (Terraform + images + DDL)
make deploy

# 3. Seed databases with synthetic data
make seed

# 4. Run the full pipeline (dbt + feature computation)
make pipeline

# 5. Tear down when done (saves ~$0.97/hour)
make teardown
```

### Restarting After EC2 Stop

If you stopped EC2 instances to save costs and are restarting:

1. Start the EC2 instances (ClickHouse + Bastion) from AWS Console
2. Wait 2-3 minutes for services to boot
3. SSH to bastion and set up tunnels:
   ```bash
   ssh -L 9000:<CH_PRIVATE_IP>:9000 -L 3000:<CH_PRIVATE_IP>:3000 \
       -i ~/.ssh/paystream-bastion.pem ec2-user@<BASTION_EIP> -N &
   ```
4. Run the recovery script:
   ```bash
   make post-restart
   ```

This checks all 7 services and auto-restarts Debezium connector tasks if they failed during the shutdown. The most common issue is the Debezium PG connector losing its replication slot connection — the script handles this automatically. If RDS ran out of storage (WAL accumulation), the script provides the exact `aws rds modify-db-instance` command to expand it.

### Individual Phase Commands

```bash
make init                  # terraform init
make plan                  # terraform plan
make apply                 # terraform apply (~20 min)
make push-images           # Build + push Debezium Docker images
make apply-bronze-ddl      # ClickHouse Bronze layer DDL
make apply-silver-ddl      # ClickHouse Silver layer DDL + MVs
make apply-gold-ddl        # ClickHouse Gold layer DDL (empty)
make apply-feature-ddl     # Feature Store DDL (empty)
make register-connectors   # Register Debezium CDC connectors
make compute-features      # Run feature computation
make provision-grafana     # Provision Grafana dashboards + alerts
make stress-test           # Run stress test suite
```

---

## Access via Bastion

All services are in private subnets. Access through the bastion host:

```bash
# ClickHouse (native protocol)
ssh -i ~/.ssh/paystream-bastion.pem \
    -L 9000:CLICKHOUSE_PRIVATE_IP:9000 \
    ec2-user@BASTION_EIP

# ClickHouse (HTTP)
ssh -i ~/.ssh/paystream-bastion.pem \
    -L 8123:CLICKHOUSE_PRIVATE_IP:8123 \
    ec2-user@BASTION_EIP

# FastAPI
ssh -i ~/.ssh/paystream-bastion.pem \
    -L 8000:FASTAPI_ALB_DNS:80 \
    ec2-user@BASTION_EIP
```

Replace `CLICKHOUSE_PRIVATE_IP`, `BASTION_EIP`, and `FASTAPI_ALB_DNS` with values from Terraform outputs:

```bash
cd terraform && terraform output
```

---

## Feature Store API

The Feature API serves pre-computed credit risk features with **P99 < 6ms** (target: < 50ms).

**Live endpoint:** `http://paystream-fastapi-alb-1584201898.eu-north-1.elb.amazonaws.com`

### Get Features for a User (real-time)

```bash
curl http://<ALB_DNS>/features/user/5003
```

Response:

```json
{
  "user_id": 5003,
  "as_of": null,
  "feature_version": "v2.1.0",
  "latency_ms": 5.3,
  "features": {
    "snapshot_ts": "2024-12-31T23:59:59",
    "tx_velocity_7d": 1,
    "tx_velocity_30d": 1,
    "avg_tx_amount_30d": "2742.58",
    "repayment_rate_90d": 1.0,
    "merchant_diversity_30d": 1,
    "declined_rate_7d": 0.0,
    "active_installments": 0,
    "days_since_first_tx": 330
  }
}
```

### Point-in-Time Query (backtesting)

Two snapshots exist (Sep 2024 + Dec 2024). Temporal queries return different data:

```bash
# Returns Dec 2024 snapshot (days_since_first_tx=287)
curl "http://<ALB_DNS>/features/user/12345"

# Returns Sep 2024 snapshot (days_since_first_tx=166)
curl "http://<ALB_DNS>/features/user/12345?as_of=2024-09-15T00:00:00"
```

### Health Check

```bash
curl http://<ALB_DNS>/health
# {"status":"healthy","clickhouse":"ok","version":"v2.1.0"}
```

### Prometheus Metrics

```bash
curl http://<ALB_DNS>/metrics
# paystream_feature_request_latency_seconds_bucket{le="0.01"} 1.0
# paystream_feature_requests_total{status="ok"} 1.0
```

---

## ClickHouse Data Layers

| Layer | Database | Engine Types | Data Source |
|---|---|---|---|
| Bronze | `bronze` | Kafka Engine + MergeTree | CDC from MSK |
| Silver | `silver` | ReplacingMergeTree, AggregatingMergeTree | Materialized Views from Bronze |
| Gold | `gold` | SummingMergeTree | dbt transformations (Phase 3) |
| Feature Store | `feature_store` | ReplacingMergeTree | Python computation via clickhouse-driver (Phase 4) |

### Naming Conventions

- Bronze (PG): `bronze.pg_{table}_kafka`, `bronze.pg_{table}_raw`, `bronze.mv_pg_{table}`
- Bronze (Mongo): `bronze.mongo_{collection}_kafka`, `bronze.mongo_{collection}_raw`, `bronze.mv_mongo_{collection}`
- Silver: `silver.{table}_silver`
- Gold: `gold.{metric_name}`
- Feature Store: `feature_store.user_credit_features`, `feature_store.drift_metrics`

---

## Dashboards

Six Grafana dashboards provisioned on self-hosted Grafana (ClickHouse EC2 port 3000, via SSH tunnel):

### 1. Merchant Operations ([screenshot](docs/screenshots/merchant_operations.png))
- GMV by merchant (time series), approval rate trend, BNPL penetration (gauge)
- Decision latency P50/P95/P99, top 10 merchants by GMV

### 2. Feature Store Health ([screenshot](docs/screenshots/feature_store_health.png))
- Feature freshness (time since last write), API P99 latency (Prometheus)
- Feature row count, version distribution, request rate

### 3. Feature Drift Monitor ([screenshot](docs/screenshots/feature_drift_monitor.png))
- Drift score per feature (8 lines), drift detected status (red/green)
- Baseline vs current median, IQR threshold at 3.0
- Data source: `feature_store.drift_metrics` (ClickHouse, not AMP)

### 4. Pipeline SLOs ([screenshot](docs/screenshots/pipeline_slos.png))
- Ingestion status, dbt run duration, Gold layer freshness
- Feature pipeline last success, settlement reconciliation status, SLO summary table

### 5. FinOps ([screenshot](docs/screenshots/finops.png))
- Storage by database layer (`system.parts`), query cost top 10 (`system.query_log`)
- Table engine distribution, API invocations

### 6. Pipeline Overview
- Latest DAG audit status (10 DAGs), DQ results summary (24h)
- Feature Store health (user count, snapshot count), Bronze row counts

### 8 Grafana Alert Rules + 1 CloudWatch Alarm

| Alert | Severity | Condition |
|-------|----------|-----------|
| DQ Check Failed | Critical | gold.dq_results status=fail in last 1h |
| Pipeline DAG Failed | Critical | gold.pipeline_audit_log status=failed in last 1h |
| Ingestion Flatline | Critical | 0 new Bronze rows in 5 min |
| Approval Rate Drop | Warning | Approval rate < 50% in 1h |
| Feature Pipeline Stale | Warning | Feature Store > 6 hours old |
| Feature Drift Detected | Warning | drift_metrics.is_drifted = 1 |
| Settlement Mismatch | Warning | Any mismatch in yesterday's settlements |
| Bronze Ingestion Lag | Warning | max(_ingested_at) > 60 min old |
| RDS Storage Low (CloudWatch) | Alarm | FreeStorageSpace < 5GB |

**Alerting chain:** Grafana webhook -> API Gateway -> Lambda (`paystream-grafana-sns-bridge`) -> SNS -> email. Terraform-managed.

---

## Data Quality & Production Hardening (Phase 7)

| Component | Count | Details |
|-----------|-------|---------|
| dbt tests | 55 | 53 pass, 2 warn, 0 error (7 Bronze PK + 30 Silver + 4 Gold + 9 contract + 5 pre-existing) |
| Runtime DQ checks | 12/cycle | 4 feature validation + 3 DQ validation + 5 schema drift |
| Data contracts | 3 | bronze_to_silver.yml, silver_to_gold.yml, gold_to_feature_store.yml |
| Grafana alerts | 8 | 3 critical + 5 warning severity |
| CloudWatch alarms | 1 | RDS storage low (< 5GB) |
| Audit trail | 10/10 DAGs | `gold.pipeline_audit_log` + `silver.update_audit_log` + `silver.delete_audit_log` |
| Schema migrations | 4 | Tracked in `gold.schema_versions` with MD5 checksums |
| Circuit breaker | 3 failures / 30s recovery | FastAPI → ClickHouse connection protection |
| Pydantic validation | 8 features | 503 on invalid data, Prometheus counter for failures |

### 10 Airflow DAGs

| DAG | Schedule | Purpose |
|-----|----------|---------|
| `dbt_daily_dwh` | Daily 03:00 | Run dbt Gold models |
| `dbt_hourly_snapshots` | Hourly | Run SCD Type 2 snapshots |
| `feature_pipeline` | Every 4h | Compute + write 8 credit risk features |
| `feature_drift_monitor` | Hourly | PSI-based drift detection on 8 features |
| `settlement_reconciliation` | Daily 06:00 | Cross-check transaction vs repayment totals |
| `data_quality_gate` | Daily 04:00 | Run dbt tests + write results |
| `dq_validation` | Every 4h | Feature Store completeness/null/Gold checks + quality gate |
| `schema_drift_detector` | Every 6h | Compare Avro schemas vs ClickHouse Bronze columns |
| `debezium_health_check` | Every 5 min | Check connector status, auto-restart failed tasks |
| `audit_log_compaction` | Daily 02:00 | Compact old audit log entries |

---

## Bug Log Summary

15 bugs encountered and resolved across Phases 1-5. Full details in [`docs/bug_log.md`](docs/bug_log.md).

| # | Bug | Root Cause (short) |
|---|-----|--------------------|
| 1 | MSK Serverless has no SCRAM endpoint | Serverless = IAM only; ClickHouse needs SCRAM |
| 2 | DocumentDB change streams silent | Must run `modifyChangeStreams` admin command |
| 3 | ClickHouse SSL handshake failure | Wrong CA bundle (RDS vs system) |
| 4 | DATE columns arrive as Int32 | Debezium Avro int encoding for dates |
| 5 | Silver TTL deletes all rows | DateTime64 overflow wraps to past |
| 6 | View columns have alias prefixes | ClickHouse 24.8 new query analyzer |
| 7 | dbt schema name concatenation | dbt-clickhouse adapter behavior |
| 8 | Spark JDBC DateTime64 overflow | Java datetime range exceeded |
| 9 | MWAA can't install C-extensions | No build tools in MWAA pip env |
| 10 | HTTP JSONEachRow returns strings | Format serializes all as strings |
| 11 | ALB health check cross-subnet | SG rules don't match ALB ENI IPs |
| 12 | SQL aliases lost in HTTP response | Qualified names preserved over aliases |
| 13 | Mongo CDC topics have 4 segments | Debezium includes database name |
| 14 | MWAA pip reports false SUCCESS | C-extension compile fails silently |
| 15 | Insert deduplication blocks backfill | MergeTree default dedup enabled |

---

## SLO Results (Measured)

| SLO | Target | Measured | Status |
|-----|--------|----------|--------|
| Feature Store freshness | < 6 hours | < 1 hour | PASS |
| Feature API P99 latency | < 50ms | 5.5ms | PASS |
| Gold layer freshness | < 25 hours | < 1 hour | PASS |
| Ingestion latency P95 | < 30 seconds | < 5 seconds | PASS |
| Settlement reconciliation | Completes by 6 AM | Complete | PASS |
| Feature drift detection | < 1 hour | < 5 minutes | PASS |

---

## Key Architecture Decisions

| ADR | Decision | Rationale |
|-----|----------|-----------|
| ADR-001 | Full AWS, no local Kind/Strimzi | Production-grade portfolio project; cost controlled via `terraform destroy` |
| ADR-002 | Single AZ (eu-north-1a) | Cost reduction for dev/demo; multi-AZ documented as production improvement |
| ADR-003 | DocumentDB over MongoDB on EC2 | Insert-only event collections; `fullDocumentBeforeChange` not needed |
| ADR-004 | MSK Provisioned with dual auth (IAM + SCRAM) | MSK Serverless has no SCRAM; ClickHouse librdkafka requires SCRAM-SHA-512. Discovered during Phase 1 build. |
| ADR-005 | Feature computation via ClickHouse SQL, not EMR Serverless | Spark JDBC DateTime64 overflow + MWAA can't install C-extensions. ClickHouse SQL in MWAA DAG computes all 8 features directly. EMR Spark code preserved as reference. |
| ADR-006 | Self-hosted Grafana, not AMG | Amazon Managed Grafana not available in eu-north-1. Grafana OSS installed on ClickHouse EC2 via userdata.sh. |
| ADR-007 | Delivery semantics: at-least-once + dedup | Bronze=at-least-once (Kafka Engine), Silver=exactly-once (ReplacingMergeTree FINAL), API=ORDER BY DESC LIMIT 1 (latest version). See [ADR-007](docs/architecture-decisions/ADR-007-delivery-semantics.md). |

---

## Architecture Deviations (Engineering Decisions)

Five major deviations from the original plan, each resolved through engineering problem-solving:

### 1. MSK Serverless -> MSK Provisioned
**Problem:** MSK Serverless supports only IAM auth. ClickHouse's librdkafka requires SCRAM-SHA-512.
**Solution:** Switched to MSK Provisioned (kafka.t3.small x 2) with dual auth: IAM for Java clients (Debezium, Schema Registry), SCRAM for ClickHouse.

### 2. AMG -> Self-hosted Grafana
**Problem:** Amazon Managed Grafana is not available in eu-north-1 (Stockholm).
**Solution:** Installed Grafana OSS 11.0 on the ClickHouse EC2 instance via userdata.sh. Provisioned dashboards and alerts via Grafana HTTP API.

### 3. AMP remote-write -> ClickHouse drift_metrics table
**Problem:** AMP remote-write requires the snappy C-extension, which can't be installed in MWAA.
**Solution:** Drift metrics written directly to `feature_store.drift_metrics` table via ClickHouse HTTP. AMP still receives FastAPI Prometheus metrics (scraped, not pushed).

### 4. Debezium timestamp microseconds vs milliseconds
**Problem:** Debezium PostgreSQL connector sends `TIMESTAMP` columns as microseconds (adaptive mode default), but Bronze MVs used `fromUnixTimestamp64Milli` (expects milliseconds). This pushed all dates to year 2299.
**Solution:** Changed 5 Bronze MVs to use `fromUnixTimestamp64Micro`. Corrected existing data via EXCHANGE TABLE. Added far-future cap in feature computation as safety guard. This debugging story -- from QA audit (score 52) through root cause diagnosis to verified fix (score 91) -- demonstrates real-world CDC pipeline debugging.

### 5. Grafana -> SNS via Lambda bridge
**Problem:** Grafana has no native SNS integration. ClickHouse EC2 is in a private subnet.
**Solution:** Terraform-managed Lambda function + API Gateway HTTP API. Grafana fires webhook -> API Gateway -> Lambda publishes to SNS -> email. Full E2E chain verified.

---

## Production Improvements

These items are documented but intentionally not built (scope control):

1. **Multi-AZ deployment** -- 3 subnets per tier, HA NAT gateway, cross-AZ RDS replica
2. **ClickHouse cluster** -- 3-node ReplicatedMergeTree with ZooKeeper/Keeper
3. **Blue/green deployments** -- ECS service with CodeDeploy for zero-downtime FastAPI updates
4. **Feature Store versioning** -- MLflow or Feast integration for model-feature lineage
5. **Data quality alerts** -- Great Expectations suite with PagerDuty integration
6. **CI/CD pipeline** -- GitHub Actions for Terraform plan/apply, dbt test, API integration tests
7. **Secrets rotation** -- Automated rotation for RDS, DocumentDB, and SCRAM credentials
8. **Backpressure handling** -- Kafka consumer lag-based autoscaling for Debezium ECS tasks

---

## Repository Structure

```
paystream/
  terraform/              # 12 Terraform modules (VPC, RDS, DocumentDB, MSK, etc.)
  clickhouse/             # ClickHouse DDL (Bronze, Silver, Gold, Feature Store)
  debezium/               # Debezium Docker configs and connector JSON
  dbt/                    # dbt project (staging, intermediate, Gold models)
  scripts/                # Deployment, seed, verification, and feature scripts
  spark/                  # EMR Serverless Spark jobs (reference — JDBC blocked)
  api/                    # FastAPI Feature Store API (ECS Fargate + ALB)
  dags/                   # 10 Airflow DAGs (synced to MWAA S3)
  grafana/                # 6 dashboards, 8 alert rules, datasources
  stress_test/            # 8-wave stress test framework + SLO results
  contracts/              # 3 data contracts (Bronze->Silver, Silver->Gold, Gold->FS)
  migrations/             # 4 ClickHouse schema migration files
  docs/                   # Bug log, QA report, ADRs, runbooks, screenshots
  versions.yaml           # Single source of truth for all component versions
  Makefile                # Composite build targets
```

---

## Verification

Each phase has a verification script:

```bash
make verify-phase1    # 12 checks: Terraform, CDC, Bronze
make verify-phase2    # Silver MVs, Gold DDL, Feature Store DDL
make verify-phase3    # dbt models, Gold data, snapshots
make verify-phase4    # Feature computation, Delta Lake, ClickHouse features
make verify-phase5    # FastAPI, DAGs, MWAA health
make verify-phase6    # Dashboards, stress test, docs
make verify-phase7    # DQ framework, audit trail, alerting, circuit breaker
make verify-clean     # Full teardown verification
```

---

## Cost Breakdown

Estimated cost per 6-hour session: **~$5.80**

| Service | Hourly Cost | 6-Hour Cost |
|---------|------------|-------------|
| MSK Provisioned (t3.small x2) | $0.14 | $0.84 |
| RDS PostgreSQL (db.t3.medium) | $0.07 | $0.42 |
| DocumentDB (db.t3.medium) | $0.08 | $0.48 |
| EC2 ClickHouse (r6i.large) | $0.15 | $0.90 |
| EC2 Bastion (t3.micro) | $0.01 | $0.06 |
| ECS Fargate (4 tasks) | $0.15 | $0.90 |
| MWAA (mw1.small) | $0.35 | $2.10 |
| NAT Gateway | $0.05 | $0.30 |
| S3 + data transfer | $0.03 | $0.18 |
| **Total** | **~$0.97** | **~$5.80** |

Always run `make teardown` when done to avoid ongoing charges.

---

## QA Score Journey

| Audit | Score | Key Change |
|-------|:-----:|------------|
| Initial audit | **52** | 3 critical defects: year-2299 timestamps cascading to feature corruption |
| Post timestamp fix | **75** | Fixed Bronze MVs (Milli->Micro), re-computed features, RDS storage expanded |
| Post D-5/D-6/D-8/D-9 fixes | **83** | VPC latency proven (P99=12ms), dbt via bastion, TF drift documented, 10/10 DAGs |
| Post 7 QA-prescribed fixes | **91** | Gold DQ checks, 2nd temporal snapshot, Pipeline Overview dashboard, Debezium audit fix |

Full QA report: [`docs/qa-audit-report.md`](docs/qa-audit-report.md)

---

## License

Internal project -- not for distribution.

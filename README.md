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

**Orchestration:** MWAA (Airflow 2.10) -- 7 DAGs managing dbt, feature computation, drift detection, and health checks.

**Observability:** Amazon Managed Grafana + Prometheus -- 4 dashboards with alerting.

---

## Tech Stack

| Component | Service | Version |
|---|---|---|
| Transactional DB | RDS PostgreSQL | 15 |
| Behavioural DB | Amazon DocumentDB | 6.0 |
| Streaming | MSK Provisioned | Kafka 3.6.0 |
| CDC | Debezium on ECS Fargate | 2.7.0 |
| Schema Registry | Confluent on ECS Fargate | 7.6.1 |
| OLAP Warehouse | ClickHouse on EC2 (r6i.large) | 24.8 |
| Batch Compute | EMR Serverless (Spark) | 3.5.1 |
| Table Format | Delta Lake on S3 | 3.2.0 |
| Transformations | dbt-core + dbt-clickhouse | 1.8.0 |
| Feature API | FastAPI on ECS Fargate + ALB | 0.111.0 |
| Orchestration | MWAA (Airflow) | 2.10.0 |
| Monitoring | Amazon Managed Grafana + Prometheus | -- |
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

The Feature API serves pre-computed credit risk features with P99 < 50ms.

### Get Features for a User

```bash
curl http://localhost:8000/features/5002
```

Response:

```json
{
  "user_id": 5002,
  "tx_velocity_7d": 3,
  "tx_velocity_30d": 12,
  "avg_tx_amount_30d": 245.50,
  "repayment_rate_90d": 0.94,
  "merchant_diversity_30d": 5,
  "feature_version": "2026-03-29T00:00:00",
  "valid_from": "2026-03-29T00:00:00"
}
```

### Health Check

```bash
curl http://localhost:8000/health
```

### Batch Lookup

```bash
curl -X POST http://localhost:8000/features/batch \
  -H "Content-Type: application/json" \
  -d '{"user_ids": [5001, 5002, 5003]}'
```

---

## ClickHouse Data Layers

| Layer | Database | Engine Types | Data Source |
|---|---|---|---|
| Bronze | `bronze` | Kafka Engine + MergeTree | CDC from MSK |
| Silver | `silver` | ReplacingMergeTree, AggregatingMergeTree | Materialized Views from Bronze |
| Gold | `gold` | SummingMergeTree | dbt transformations (Phase 3) |
| Feature Store | `feature_store` | MergeTree | Spark/Python computation (Phase 4) |

### Naming Conventions

- Bronze (PG): `bronze.pg_{table}_kafka`, `bronze.pg_{table}_raw`, `bronze.mv_pg_{table}`
- Bronze (Mongo): `bronze.mongo_{collection}_kafka`, `bronze.mongo_{collection}_raw`, `bronze.mv_mongo_{collection}`
- Silver: `silver.{table}_silver`
- Gold: `gold.{metric_name}`
- Feature Store: `feature_store.user_credit_features`

---

## Dashboards

Four Grafana dashboards provisioned via JSON API:

### 1. Pipeline Health (`docs/screenshots/pipeline_health.png`)
- CDC lag per connector (seconds)
- Kafka consumer group offsets
- ClickHouse insert rate (rows/sec)
- MSK broker metrics

### 2. Feature Store SLOs (`docs/screenshots/feature_store_slos.png`)
- API P50/P95/P99 latency
- Feature freshness (time since last computation)
- Drift scores per feature
- Cache hit ratio

### 3. FinOps (`docs/screenshots/finops.png`)
- Cost per service (estimated)
- ClickHouse disk usage by database
- MSK throughput (bytes in/out)
- ECS task CPU/memory utilization

### 4. Risk Overview (`docs/screenshots/risk_overview.png`)
- Daily approval/decline rates
- Total credit exposure
- Default rate trends
- Merchant risk tier distribution

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

## SLO Results

| SLO | Target | Actual | Status |
|-----|--------|--------|--------|
| Feature API P99 latency | < 50ms | ~35ms | PASS |
| Feature freshness | < 1 hour | ~30 min (DAG schedule) | PASS |
| CDC lag (steady state) | < 30s | ~5s | PASS |
| CDC lag (stress test) | < 60s | ~25s | PASS |
| dbt full run | < 10 min | ~4 min | PASS |
| Feature computation | < 15 min | ~6 min | PASS |
| Drift detection | Daily | Every 24h via DAG | PASS |
| Dashboard load time | < 5s | ~2s | PASS |

---

## Key Architecture Decisions

| ADR | Decision | Rationale |
|-----|----------|-----------|
| ADR-001 | Full AWS, no local Kind/Strimzi | Production-grade portfolio project; cost controlled via `terraform destroy` |
| ADR-002 | Single AZ (eu-north-1a) | Cost reduction for dev/demo; multi-AZ documented as production improvement |
| ADR-003 | DocumentDB over MongoDB on EC2 | Insert-only event collections; `fullDocumentBeforeChange` not needed |
| ADR-004 | MSK dual auth (IAM + SCRAM) | Java clients use IAM; ClickHouse librdkafka requires SCRAM-SHA-512 |
| ADR-005 | Feature Store dual write (Delta Lake + ClickHouse) | Delta Lake for audit/backfill; ClickHouse for sub-50ms serving |

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
  dags/                   # Airflow DAGs (synced to S3 for MWAA)
  fastapi/                # Feature API service
  grafana/                # Dashboard JSON definitions
  docs/                   # Bug log, demo queries, screenshots
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
make verify-clean     # Full teardown verification
```

---

## Cost Breakdown

Estimated cost per 6-hour session: **~$5.80**

| Service | Hourly Cost | 6-Hour Cost |
|---------|------------|-------------|
| MSK Provisioned (t3.small x2) | $0.14 | $0.84 |
| RDS PostgreSQL (db.t3.micro) | $0.02 | $0.12 |
| DocumentDB (db.t3.medium) | $0.08 | $0.48 |
| EC2 ClickHouse (r6i.large) | $0.15 | $0.90 |
| EC2 Bastion (t3.micro) | $0.01 | $0.06 |
| ECS Fargate (3 tasks) | $0.12 | $0.72 |
| MWAA (mw1.small) | $0.35 | $2.10 |
| NAT Gateway | $0.05 | $0.30 |
| S3 + data transfer | $0.03 | $0.18 |
| **Total** | **~$0.97** | **~$5.80** |

Always run `make teardown` when done to avoid ongoing charges.

---

## License

Internal project -- not for distribution.

# PayStream — Claude Code Rules

## Identity
You are the builder for the PayStream BNPL Data Platform & Feature Store. You execute approved plans. You do not make architecture decisions.

## Source of Truth
- **Execution plans live in Notion.** Every phase has a page under the Master Execution Plan. Read the full phase plan from Notion before writing any code.
- **Master Execution Plan:** https://www.notion.so/32db71eeacba8118bbf7d6742777f8b5
- **Plan Documentation Standard:** https://www.notion.so/326b71eeacba81dd9596cc685c7eb928
- **PayStream Project Page:** https://www.notion.so/32db71eeacba81718248c9f60bf05f6f
- **GitHub repo:** https://github.com/tarigelamin1997/paystream

## Project Configuration
- **`.claude/settings.json`** — Claude Code settings with schema validation and hooks. Do not modify.
- **PreToolUse hook active:** Any file write exceeding 800 lines is BLOCKED automatically. If you hit this, split the file into smaller modules. Do not disable the hook.

## Execution Rules

### Read Before You Build
- Read the FULL phase plan from Notion before writing any file.
- Read the Cross-Audit findings for the stage containing the current phase — amendments may have been applied to the plan after initial authoring:
  - Stage A (Phases 1+2): https://www.notion.so/32db71eeacba81d3b9afd0b1c812a24e
  - Stage B (Phases 3+4): https://www.notion.so/32db71eeacba81deb0bcd979021e3610
  - Stage C (Phases 5+6): https://www.notion.so/32db71eeacba819cb0bfcbfee543f9ab
  - Final Cross-Validation: https://www.notion.so/32db71eeacba81919bbcffbf89cf23ae

### Follow the Plan Exactly
- Every file you create must appear in the phase's Repo Structure section. No extra files. No missing files.
- Configuration blocks in the plan are COMPLETE. Copy them exactly. Do not abbreviate, summarize, refactor, or "improve" them.
- Follow the Apply Sequence in exact numbered order. Each step has WHY, WAIT FOR, and FAILURE MODE — respect all three.
- Do not skip steps. Do not reorder steps. Do not combine steps.

### Versions
- `versions.yaml` at repo root is the single source of truth for ALL component versions.
- Never hard-code a version in a Dockerfile, Terraform file, requirements.txt, or any config file. Reference versions.yaml or use the exact version declared there.
- If you need a version number, check versions.yaml first.

### Secrets
- NEVER commit secrets, passwords, API keys, or credentials to the repo.
- All database credentials stored in AWS Secrets Manager.
- ECS task definitions receive credentials via environment variables from Secrets Manager.
- ClickHouse MSK SCRAM credentials injected from Secrets Manager via Terraform user-data script.
- Debezium connector configs use `<FROM_SECRETS_MANAGER>` placeholder syntax.
- dbt profiles.yml uses `env_var()` exclusively.
- FastAPI config.py reads from environment variables only.

### .gitignore
- .gitignore must exist before any other file is created.
- Must cover: `.terraform/`, `*.tfstate*`, `*.pem`, `__pycache__/`, `.env`, `*.pyc`, `.pytest_cache/`.

### Phase Boundaries — Do Not Cross
- Only create/modify files owned by the current phase.
- Never modify files from prior phases unless the plan explicitly says to.
- Never write to ClickHouse databases owned by other phases:
  - `bronze` = Phase 1
  - `silver` (tables + MVs) = Phase 2
  - `gold` (DDL) = Phase 2, (data) = Phase 3 dbt + Phase 5 DAGs
  - `feature_store` (DDL) = Phase 2, (data) = Phase 4 Spark
- Never deploy DAGs to MWAA before Phase 5.
- Never create Grafana dashboards before Phase 6.

### Verification
- After completing the Apply Sequence, run `make verify-phaseN`. ALL checks must pass.
- If any check fails, report: the check number, the exact error, and what you see in logs.
- Do not mark a phase complete until verify passes.
- **After verify passes and the Execution Log is written to Notion, STOP. Do not start the next phase. Wait for Tarig's explicit confirmation before proceeding to the next phase. You do not decide when to move forward — Tarig does.**

### Execution Log (Mandatory — write to Notion after each phase)
After completing a phase (verify passes), create a Notion page titled "Phase {N} — Execution Log" as a child of the phase's plan page. Structure:

**1. Execution Summary** (2-3 sentences: what was built, total time, final verify result)

**2. Deviations from Plan** (MOST IMPORTANT SECTION)
For each deviation:
- Step number from Apply Sequence
- What the plan said to do
- What you actually did and WHY
- Whether the deviation affects downstream phases

If zero deviations: write "None — executed exactly as planned."

**3. Errors Encountered**
For each error:
- Step number
- Error message (exact)
- Root cause
- Fix applied
- Whether the fix is plan-compatible or a deviation

If zero errors: write "None — all steps completed on first attempt."

**4. Files Created Checklist**
List every file from the Repo Structure section with a checkmark (created) or X (not created, with reason).

**5. Verify Results**
Each verify check number, pass/fail, and the actual output value.

**Rules for this log:**
- Do NOT log steps that went exactly as planned — just confirm them in a single line ("Steps 1-4: executed as planned").
- DO expand on anything that went differently, failed, or required a judgment call.
- This log is for Tarig to review. Write it for a human reader, not for another LLM.
- Create the Notion page AFTER verify passes, not during execution.
- After writing the execution log, update the phase plan page's Status line: change "🔲 Built" to "✅ Built" and "🔲 Verified" to "✅ Verified" using the Notion update tool.

### Error Handling
- If ANY step fails: STOP. Report the step number, the exact error, and relevant logs.
- Do not attempt workarounds or fixes without reporting first.
- Do not silently retry failed commands.
- Do not skip a failed step and continue to the next.

### Code Quality
- All code must be production-grade: idempotent, observable, documented with rationale.
- All SQL uses `CREATE TABLE IF NOT EXISTS` or `CREATE MATERIALIZED VIEW IF NOT EXISTS`.
- All bash scripts start with `set -euo pipefail`.
- All Python follows standard formatting. No unused imports. No bare excepts.
- All Terraform resources support `terraform destroy` — no `prevent_destroy`, no `deletion_protection = true`.

## Deployment Target
**Full AWS.** No local Kind cluster. No Strimzi. No MinIO. No spark-operator.

**Region:** `eu-north-1` (Stockholm)
**AZ:** Single — `eu-north-1a` (with `eu-north-1b` private subnet for MWAA only)

## AWS Service Map

| Component | AWS Service | Access Pattern |
|---|---|---|
| Transactional DB | RDS PostgreSQL 15 | Private subnet, port 5432 |
| Behavioural DB | Amazon DocumentDB 6.0 | Private subnet, port 27017, TLS enforced |
| Streaming | MSK Provisioned (kafka.t3.small × 2) | IAM auth (Debezium, Schema Registry) + SCRAM-SHA-512 (ClickHouse). MSK Serverless does not support SCRAM. |
| CDC | Debezium 2.7 on ECS Fargate | 2 tasks: PG connector (1vCPU/2GB) + Mongo connector (0.5vCPU/1GB) |
| Schema Registry | Confluent 7.6.1 on ECS Fargate | 0.5vCPU/1GB, Service Discovery: schema-registry.paystream.local |
| Warehouse | ClickHouse 24.8 on EC2 r6i.large | Private subnet, ports 9000 (native) + 8123 (HTTP), bastion SSH tunnel |
| Batch Compute | EMR Serverless (Spark 3.5) | Pay-per-query, Delta Lake JARs in app config |
| Table Format | Delta Lake 3.x on S3 | s3://paystream-features/user_credit/ |
| Orchestration | MWAA (Airflow 2.10) | DAGs synced from s3://paystream-mwaa-dags/dags/ |
| Feature API | FastAPI on ECS Fargate + ALB | 0.5vCPU/1GB, ALB port 80 → container 8000 |
| Object Storage | Amazon S3 | 6 buckets: paystream-{bronze,silver,gold,features,delta,mwaa-dags} |
| Observability | Self-hosted Grafana on ClickHouse EC2 (port 3000) + AMP (Prometheus) | Grafana OSS with ClickHouse plugin + AWS SDK plugin. AMP with sigv4 auth. AMG not available in eu-north-1. |
| Access | Bastion EC2 t3.micro | Public subnet, Elastic IP, SSH tunnel to all private services |
| IaC | Terraform 1.7.5 | 12 modules: vpc, rds, documentdb, msk, ecs, clickhouse, emr, s3, mwaa, observability (AMP only), iam, bastion. Grafana installed on ClickHouse EC2 via userdata.sh. |

## Stack Versions (from versions.yaml)
```
terraform:            1.7.5
aws_provider:         5.40.0
postgresql:           15
documentdb:           6.0
clickhouse:           24.8
kafka:                3.6.0        (MSK Provisioned, kafka.t3.small × 2)
debezium:             2.7.0
schema_registry:      7.6.1
spark:                3.5.1
delta_lake:           3.2.0
airflow:              2.10.0
dbt_core:             1.8.0
dbt_clickhouse:       1.8.0
great_expectations:   0.18.0
dbt_expectations:     0.10.3
fastapi:              0.111.0
uvicorn:              0.30.0
clickhouse_driver:    0.2.6
clickhouse_jdbc:      0.6.0
prometheus_client:    0.20.0
pydantic:             2.7.0
python:               3.12
```

## Key Architectural Decisions (LOCKED — do not revisit)

1. **Full AWS deployment.** No local Kind. No Strimzi. No MinIO. Cost controlled via `terraform destroy`.
2. **Single AZ** (`eu-north-1a`). Multi-AZ is a documented production improvement, not built.
3. **DocumentDB, not MongoDB EC2.** Insert-only event collections — `fullDocumentBeforeChange` not needed. ADR-005.
4. **MSK dual auth.** IAM for Java clients (Debezium, Schema Registry). SCRAM-SHA-512 for ClickHouse (librdkafka can't do IAM).
5. **Two separate Debezium ECS tasks.** PG + Mongo. Independent failure domains, independent IAM roles.
6. **Debezium `decimal.handling.mode=string`.** Avro Decimal bytes unreadable by ClickHouse. MV uses `toDecimal64()`.
7. **ClickHouse in private subnet.** Bastion SSH tunnel for access. Elastic IP on bastion.
8. **MergeTree for transactions** (immutable facts). ReplacingMergeTree for repayments/users/merchants (mutable state). AggregatingMergeTree for active credit (running sum).
9. **dbt `delete+insert` incremental** on SummingMergeTree Gold tables. Prevents double-counting.
10. **Feature Store dual write.** Delta Lake (audit/backfill) + ClickHouse (serving). Same `(user_id, valid_from)` key.
11. **FastAPI on ECS Fargate + ALB.** Not Lambda — cold starts break P99 < 50ms SLA.
12. **Drift metrics to AMP** via sigv4 remote-write. Not ClickHouse — Grafana queries AMP natively. Grafana self-hosted on ClickHouse EC2 (AMG not available in eu-north-1).

## Naming Conventions

### AWS Resources
All AWS resources use `paystream-` prefix: `paystream-vpc`, `paystream-rds`, `paystream-docdb`, `paystream-msk`, `paystream-clickhouse`, `paystream-bastion`, `paystream-mwaa`, `paystream-fastapi`, `paystream-fastapi-alb`.

### Kafka Topics
- PostgreSQL CDC: `paystream.public.{table}` (e.g., `paystream.public.transactions`)
- DocumentDB CDC: `paystream.mongo.{collection}` (e.g., `paystream.mongo.app_events`)
- Dead letter queue: `paystream.dlq`

### ClickHouse
- Bronze: `bronze.pg_{table}_kafka` (Kafka Engine), `bronze.pg_{table}_raw` (storage), `bronze.mv_pg_{table}` (MV)
- Bronze (Mongo): `bronze.mongo_{collection}_kafka`, `bronze.mongo_{collection}_raw`, `bronze.mv_mongo_{collection}`
- Silver: `silver.{table}_silver` (e.g., `silver.transactions_silver`)
- Gold: `gold.{table}` (e.g., `gold.merchant_daily_kpis`)
- Feature Store: `feature_store.user_credit_features`

### S3 Paths
- Delta Lake features: `s3://paystream-features/user_credit/`
- Spark jobs: `s3://paystream-delta/spark-jobs/`
- Spark JARs: `s3://paystream-delta/spark-jars/`
- Spark logs: `s3://paystream-delta/spark-logs/`
- MWAA DAGs: `s3://paystream-mwaa-dags/dags/`
- MWAA requirements: `s3://paystream-mwaa-dags/requirements.txt`

### Seed Data
- All enum/status values MUST be lowercase: `approved`, `declined`, `pending`, `cancelled`, `paid`, `overdue`, `waived`, `active`, `completed`, `defaulted`.
- Seed script uses TRUNCATE before INSERT (idempotent).
- PostgreSQL user_id range: 1–50,000. Stress test uses 100,000+.

## Phase Plan Notion Pages

| Phase | Title | Notion Page |
|---|---|---|
| 1 | Infrastructure + CDC | https://www.notion.so/32db71eeacba8146bd54e1514cf939dd |
| 2 | ClickHouse DWH (Full Schema) | https://www.notion.so/32db71eeacba8167a009d88bbd4c1b7e |
| 3 | dbt Transformation Layer | https://www.notion.so/32db71eeacba813a887aed898282ce7f |
| 4 | Feature Store (Spark + Delta Lake) | https://www.notion.so/32db71eeacba81f7b6dff99012b40238 |
| 5 | Feature API + Airflow DAGs | https://www.notion.so/32db71eeacba81b0a951ee9010a439d9 |
| 6 | Observability + Stress Test + Docs | https://www.notion.so/32db71eeacba814a9e28e9eac8c5cabb |

## Phase Ownership Map

| Phase | Owns | Creates | Does NOT Touch |
|---|---|---|---|
| 1 | Terraform (12 modules), Debezium connectors, Bronze DDL, seed data | VPC, RDS, DocumentDB, MSK, ECS (Debezium + SR), EC2 ClickHouse + Grafana, EMR app, S3, MWAA env, AMP, bastion, Bronze tables | Silver, Gold, Feature Store, DAGs, dashboards |
| 2 | Silver DDL + MVs, Gold DDL (empty), Feature Store DDL (empty) | Silver tables, Bronze→Silver MVs, Gold table structures, Feature Store table structure | Bronze tables, Gold data, Feature Store data |
| 3 | dbt project, models, snapshots, macros, tests | Staging models, intermediate views, Gold data (via dbt), SCD Type 2 snapshots, seed tables | Bronze, Silver tables, Feature Store |
| 4 | Spark jobs, Delta Lake, Feature Store data | CreditFeatureEngineer, feature_store_writer, S3 Delta files, Feature Store rows | Bronze, Silver, Gold, DAGs, dashboards |
| 5 | FastAPI, Airflow DAGs, MWAA config | ECS FastAPI service + ALB, 7 DAGs, AMP drift metrics, gold.dbt_test_results data | Bronze, Silver DDL, Gold DDL, Feature Store DDL |
| 6 | Grafana dashboards, alerts, stress test, docs | Grafana dashboards + alerts (self-hosted on ClickHouse EC2), stress test results, README, bug log, composite Makefile | All infrastructure and data from Phases 1–5 |

## What You Must Never Do
- Never make architecture decisions. If a choice is not covered in the plan, ask.
- Never use `prevent_destroy = true` or `deletion_protection = true` in Terraform.
- Never put databases or compute in public subnets.
- Never hardcode AWS credentials, IPs, or ARNs — use Terraform outputs and Secrets Manager.
- Never write directly to Silver, Gold, or Feature Store tables from scripts — use MVs (Phase 2), dbt (Phase 3), or Spark (Phase 4).
- Never deploy DAGs to MWAA before Phase 5.
- Never create Grafana dashboards manually in the Grafana UI — all provisioned via JSON + Grafana HTTP API (provision.sh).
- Never run `terraform destroy` without confirming it is intentional.
- Never create resources outside `eu-north-1`.
- Never use MSK IAM auth for ClickHouse Kafka Engine — it does not support it. Use SCRAM-SHA-512 only.
- Never skip the verification step. Every phase ends with `make verify-phaseN` passing all checks.
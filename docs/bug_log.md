# PayStream Bug Log

Bugs encountered during Phases 1-5, mined from Execution Logs. Each entry documents the bug, root cause analysis, fix applied, and why it matters in a technical interview context.

## Bug Table

| # | Bug | Root Cause | Fix | Interview Value |
|---|-----|-----------|-----|-----------------|
| 1 | MSK Serverless has no SCRAM endpoint | MSK Serverless only supports IAM auth; ClickHouse librdkafka needs SCRAM | Switched to MSK Provisioned (kafka.t3.small x2) | Demonstrates deep understanding of Kafka auth mechanisms across client libraries |
| 2 | DocumentDB change streams not capturing seed data | Change streams must be explicitly enabled via `modifyChangeStreams` admin command | Ran admin command before connector registration | Shows DocumentDB vs MongoDB operational differences |
| 3 | ClickHouse Kafka Engine SSL handshake failure | System CA bundle required for MSK TLS, not RDS-specific CA | Used `/etc/pki/tls/certs/ca-bundle.crt` | Debugging TLS certificate chains across services |
| 4 | Debezium DATE columns arrive as Int32, not String | Debezium sends Avro `int` for DATE type (days since epoch) | Changed Kafka Engine columns to Int32, MV uses `addDays()` | Understanding CDC type mapping across Avro/ClickHouse |
| 5 | Silver TTL deletes rows on OPTIMIZE | `toDateTime(DateTime64(2299))` overflows DateTime max (2106), wrapping to past date | Removed TTL from all Silver tables | Subtle ClickHouse type system behavior |
| 6 | ClickHouse 24.8 view columns retain internal alias prefixes | New query analyzer exposes `t.merchant_id` not `merchant_id` from views | Added explicit `AS` aliases in all view SELECTs | Version-specific ClickHouse behavior |
| 7 | dbt-clickhouse concatenates schema names | Profile `schema: silver` + model `+schema: gold` = `silver_gold` | Custom `generate_schema_name` macro | dbt adapter quirks |
| 8 | Spark JDBC DateTime64 overflow (year 56969) | ClickHouse DateTime64(3) far-future values overflow Java/Python datetime | Used bastion Python with clickhouse-driver instead of EMR Serverless | Cross-system type compatibility |
| 9 | MWAA cannot install C-extension packages (clickhouse-driver, snappy) | MWAA pip environment doesn't support C compilation | Rewrote clickhouse_hook.py to use HTTP interface via requests | Platform constraint workaround |
| 10 | ClickHouse HTTP JSONEachRow returns strings, not typed values | JSONEachRow format serializes all values as JSON strings | Added Row class with `_auto_convert()` for string-to-numeric casting | HTTP API response format handling |
| 11 | ALB health check fails across subnet boundaries | SG-based rules don't match ALB source IPs (from public subnet) | Added VPC CIDR-based rule (10.0.0.0/16:8000) | AWS ALB networking with Fargate |
| 12 | compute_features.py SQL column aliases lost in HTTP response | ClickHouse HTTP preserves qualified names (`tx.user_id`) not aliases | Added explicit `AS user_id` to all columns | ClickHouse HTTP vs native protocol behavior |
| 13 | Mongo CDC topic names have 4 segments, not 3 | Debezium includes database name: `prefix.database.collection` | Updated Kafka Engine topic list | Debezium naming conventions |
| 14 | MWAA requirements.txt update reports SUCCESS but packages not importable | C-extension packages fail silently during MWAA pip install | Removed C-extensions, used pure-Python alternatives | AWS managed service limitations |
| 15 | Insert deduplication in ClickHouse 24.8 | MergeTree has block-level dedup enabled by default | Used `--insert_deduplicate 0` for backfill | ClickHouse default behavior changes across versions |

## Detailed Analysis

### Bug 1: MSK Serverless SCRAM Incompatibility

**Context:** Phase 1, Terraform apply + ClickHouse Kafka Engine configuration.

**Symptoms:** ClickHouse Kafka Engine tables could not connect to MSK. Connection timeout errors in `system.kafka_log`.

**Root Cause:** MSK Serverless only supports IAM authentication. ClickHouse's Kafka Engine uses librdkafka under the hood, which does not support AWS IAM SASL. The plan specified dual auth (IAM for Java clients, SCRAM for ClickHouse), but MSK Serverless cannot provision SCRAM credentials.

**Fix:** Switched Terraform from `aws_msk_serverless_cluster` to `aws_msk_cluster` (provisioned) with `kafka.t3.small` x2 brokers. Enabled both IAM and SCRAM-SHA-512 SASL mechanisms. Created SCRAM secret in Secrets Manager and associated it with the cluster.

**Downstream Impact:** Monthly cost increase (~$60/month for t3.small x2 vs serverless). No architectural change -- dual auth works as designed.

---

### Bug 2: DocumentDB Change Streams Not Capturing Seed Data

**Context:** Phase 1, after seeding DocumentDB and registering the Mongo Debezium connector.

**Symptoms:** Debezium Mongo connector started successfully but no messages appeared on Kafka topics for DocumentDB collections.

**Root Cause:** DocumentDB requires explicit change stream enablement via the `modifyChangeStreams` admin command on each database. Unlike MongoDB, change streams are not enabled by default.

**Fix:** Added `db.adminCommand({modifyChangeStreams: 1, database: "paystream", collection: "", enable: true})` to the seed script, executed before connector registration.

**Downstream Impact:** None -- fix was applied in sequence before any downstream consumption.

---

### Bug 3: ClickHouse Kafka Engine SSL Handshake Failure

**Context:** Phase 1, ClickHouse consuming from MSK via Kafka Engine.

**Symptoms:** `NETWORK_ERROR` in ClickHouse logs: `SSL handshake failed: certificate verify failed`.

**Root Cause:** The ClickHouse Kafka Engine configuration pointed to an RDS-specific CA bundle. MSK TLS requires the system-wide CA bundle that includes Amazon Trust Services root CAs.

**Fix:** Changed `kafka_ssl_ca_location` from the RDS CA path to `/etc/pki/tls/certs/ca-bundle.crt` (Amazon Linux 2 system bundle).

**Downstream Impact:** None -- all subsequent Kafka Engine tables use the corrected path.

---

### Bug 4: Debezium DATE Columns Arrive as Int32

**Context:** Phase 2, Silver materialized views failing on date transformation.

**Symptoms:** `ILLEGAL_TYPE_OF_ARGUMENT` error in MV: cannot apply `toDate()` to Int32 column.

**Root Cause:** Debezium serializes SQL DATE type as Avro `int` (days since Unix epoch, per Avro spec). The Bronze Kafka Engine schema declared these as `String`, expecting ISO date strings.

**Fix:** Changed Bronze Kafka Engine column types from `String` to `Int32` for all DATE fields. Silver MVs use `addDays(toDate('1970-01-01'), column_name)` to reconstruct proper Date values.

**Downstream Impact:** Required re-creation of Bronze Kafka Engine tables and MVs. No data loss (Kafka Engine tables are virtual).

---

### Bug 5: Silver TTL Deletes Rows on OPTIMIZE

**Context:** Phase 2, Silver table maintenance.

**Symptoms:** Running `OPTIMIZE TABLE silver.transactions_silver FINAL` deleted all rows.

**Root Cause:** Silver tables had TTL set to `toDateTime(DateTime64(2299))` as a "never expire" sentinel. However, `DateTime` max value is 2106-02-07. The value 2299 overflows and wraps to a past date, making every row appear expired.

**Fix:** Removed TTL clauses from all Silver tables. TTL-based retention is documented as a production improvement.

**Downstream Impact:** Silver tables no longer have automatic expiry. Manual cleanup required for production use.

---

### Bug 6: ClickHouse 24.8 View Column Alias Prefixes

**Context:** Phase 2, querying views that join multiple tables.

**Symptoms:** Column names in query results included table alias prefixes (e.g., `t.merchant_id` instead of `merchant_id`). Downstream dbt models failed on column name mismatches.

**Root Cause:** ClickHouse 24.8 introduced a new query analyzer that preserves internal qualified column names in view definitions. Prior versions stripped the prefix.

**Fix:** Added explicit `AS` aliases to every column in all view SELECT statements (e.g., `t.merchant_id AS merchant_id`).

**Downstream Impact:** All views in Phase 2 were updated. dbt models in Phase 3 rely on clean column names.

---

### Bug 7: dbt-clickhouse Schema Name Concatenation

**Context:** Phase 3, dbt model materialization into Gold database.

**Symptoms:** dbt attempted to create tables in `silver_gold` database instead of `gold`.

**Root Cause:** The dbt-clickhouse adapter concatenates `profile.schema` with `model.+schema` using an underscore separator. With `schema: silver` in profiles.yml and `+schema: gold` in model config, the result is `silver_gold`.

**Fix:** Created a custom `generate_schema_name` macro in `dbt/macros/generate_schema_name.sql` that returns the model-level schema directly when specified, ignoring the profile default.

**Downstream Impact:** None -- macro applies globally to all dbt models.

---

### Bug 8: Spark JDBC DateTime64 Overflow

**Context:** Phase 4, Spark reading from ClickHouse via JDBC.

**Symptoms:** `java.lang.ArithmeticException: long overflow` when Spark reads DateTime64(3) columns with far-future values.

**Root Cause:** ClickHouse DateTime64(3) can store timestamps up to year 2299. Java `Timestamp` and Python `datetime` overflow well before that. The Silver "never expire" sentinel values (even after Bug 5 fix, some test data remained) caused the overflow.

**Fix:** Abandoned EMR Serverless JDBC approach. Used bastion-hosted Python script with `clickhouse-driver` (native protocol), which handles DateTime64 as strings when needed.

**Downstream Impact:** Feature computation runs on bastion via `compute_features.py` instead of EMR Serverless Spark. Same output, different execution path.

---

### Bug 9: MWAA C-Extension Package Installation Failure

**Context:** Phase 5, MWAA DAG execution requiring clickhouse-driver.

**Symptoms:** DAGs failed with `ModuleNotFoundError: No module named 'clickhouse_driver'` despite requirements.txt including it.

**Root Cause:** MWAA's pip environment runs on Amazon Linux 2 but does not support compiling C extensions. Packages like `clickhouse-driver` (which uses Cython) and `python-snappy` fail silently during installation.

**Fix:** Rewrote `clickhouse_hook.py` to use ClickHouse's HTTP interface via the `requests` library (pure Python, available by default in MWAA). All DAGs use HTTP queries instead of native protocol.

**Downstream Impact:** All ClickHouse interactions from MWAA use HTTP. Slight increase in query overhead but no functional difference.

---

### Bug 10: ClickHouse HTTP JSONEachRow String Serialization

**Context:** Phase 5, FastAPI and DAGs querying ClickHouse via HTTP.

**Symptoms:** Numeric values returned as strings (e.g., `"42"` instead of `42`). Feature API returned incorrect types to consumers.

**Root Cause:** ClickHouse's HTTP interface with `FORMAT JSONEachRow` serializes all values as JSON strings for consistency. The native protocol returns typed values.

**Fix:** Added a `Row` class with `_auto_convert()` method that casts string values to appropriate Python types (int, float, Decimal) based on column metadata.

**Downstream Impact:** Applied to both FastAPI and MWAA hook. All HTTP-based ClickHouse consumers use the Row class.

---

### Bug 11: ALB Health Check Cross-Subnet Failure

**Context:** Phase 5, FastAPI ECS service behind ALB.

**Symptoms:** ALB health checks returned unhealthy. ECS tasks were running and responding to direct requests.

**Root Cause:** The FastAPI security group allowed inbound on port 8000 from the ALB security group. However, ALB health check traffic originates from the ALB's ENI IP in the public subnet, which did not match the SG-to-SG rule due to cross-subnet routing.

**Fix:** Added an inbound rule allowing TCP 8000 from the entire VPC CIDR (10.0.0.0/16) to the FastAPI security group.

**Downstream Impact:** None -- security posture unchanged (ALB is the only public-facing component).

---

### Bug 12: compute_features.py Column Alias Loss

**Context:** Phase 4/5, feature computation SQL queries via HTTP.

**Symptoms:** Feature computation returned columns named `tx.user_id` instead of `user_id`, causing KeyError in Python processing code.

**Root Cause:** Same root cause as Bug 6 -- ClickHouse HTTP interface preserves qualified column names from joins. Column aliases in the SQL were ignored in the HTTP response.

**Fix:** Added explicit `AS` aliases to every column in the feature computation SQL (e.g., `tx.user_id AS user_id`).

**Downstream Impact:** None -- fix localized to compute_features.py SQL.

---

### Bug 13: Mongo CDC Topic Name 4-Segment Format

**Context:** Phase 1, Bronze Kafka Engine tables for DocumentDB collections.

**Symptoms:** Kafka Engine tables returned zero rows. No errors in logs.

**Root Cause:** Debezium for MongoDB generates topic names with 4 segments: `{prefix}.{database}.{collection}` (e.g., `paystream.paystream.app_events`). The Bronze DDL used 3-segment names (`paystream.app_events`).

**Fix:** Updated all Mongo Kafka Engine table topic references to use 4-segment names.

**Downstream Impact:** Required re-creation of Bronze Mongo Kafka Engine tables.

---

### Bug 14: MWAA Silent Package Installation Failure

**Context:** Phase 5, MWAA requirements.txt update.

**Symptoms:** MWAA environment update completed with `SUCCESS` status. DAGs failed at runtime with import errors.

**Root Cause:** MWAA reports requirements installation as successful even when individual packages fail to compile. The pip install runs in a constrained environment without build tools for C extensions.

**Fix:** Removed all C-extension packages from requirements.txt. Used pure-Python alternatives (requests for HTTP, json for serialization).

**Downstream Impact:** Same as Bug 9 -- all MWAA ClickHouse interactions use HTTP interface.

---

### Bug 15: ClickHouse Insert Deduplication During Backfill

**Context:** Phase 4, backfilling feature_store.user_credit_features.

**Symptoms:** Repeated INSERT statements produced no new rows. Row count stayed constant after multiple backfill runs.

**Root Cause:** ClickHouse MergeTree engine has block-level insert deduplication enabled by default (since 24.x). If the same data block is inserted twice, the second insert is silently deduplicated.

**Fix:** Added `SET insert_deduplicate = 0` before backfill INSERT statements (equivalent to `--insert_deduplicate 0` in clickhouse-client).

**Downstream Impact:** Only affects backfill operations. Normal CDC-driven inserts produce unique blocks and are not affected.

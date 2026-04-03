# ADR-007: Delivery Semantics and Deduplication Strategy

## Status
Accepted

## Context
PayStream ingests data via CDC (Debezium) through Kafka into ClickHouse. The delivery guarantee at each stage affects data correctness and must be explicitly documented.

## Decision

### Per-Stage Delivery Guarantees

| Stage | Guarantee | Mechanism | Risk |
|---|---|---|---|
| PostgreSQL → Debezium | At-least-once | WAL logical replication + Debezium offset tracking. Connector restart replays from last committed offset. | Duplicate events on connector restart |
| Debezium → Kafka | At-least-once | Kafka producer acks=all, no transactional producer. | Duplicate messages on producer retry |
| Kafka → ClickHouse Bronze | At-least-once | ClickHouse Kafka Engine consumer (`AvroConfluent` format, per-table consumer groups like `clickhouse_bronze_transactions`). MV restart replays from last committed offset. | Duplicate rows in Bronze tables on MV restart |
| Bronze → Silver | Deduplicated at query time | ReplacingMergeTree on PK columns. Version columns: `__source_ts_ms` (Bronze), `_version`/`updated_at` (Silver). `FINAL` keyword deduplicates at read time. | Without FINAL, queries see duplicates. Background merges eventually physical-deduplicate. |
| Silver → Gold | Deduplicated | dbt staging models query ReplacingMergeTree Silver tables with `FINAL` (`stg_users`, `stg_merchants`, `stg_repayments`). `stg_transactions` does not use FINAL because `transactions_silver` is MergeTree (immutable facts). Gold marts use `delete+insert` incremental strategy. | Correct by construction — staging layer deduplicates before aggregation. |
| Gold → Feature Store | Deduplicated | `feature_store.user_credit_features` uses ReplacingMergeTree with `snapshot_ts` as version column. Feature computation is idempotent — re-running produces same result. | Without FINAL, stale feature versions may be visible. |
| Feature Store → FastAPI | At-most-one (read) | Single ClickHouse query per API request with `ORDER BY valid_from DESC LIMIT 1`. Does NOT use FINAL — relies on ORDER BY + LIMIT to return the latest row. For point-in-time queries, temporal range filter (`valid_from <= as_of AND valid_to > as_of`) selects the correct version. | If background merge has not run, duplicate rows may exist but ORDER BY DESC LIMIT 1 still returns the latest. Consistent for the latest snapshot; may return stale data if multiple snapshots exist un-merged. |

### Why Not Exactly-Once End-to-End?

ClickHouse Kafka Engine does not support Kafka consumer transactions. The consumer commits offsets independently of the MV INSERT. On failure between INSERT and offset commit, the message is replayed and re-inserted.

This is the standard pattern for CDC-to-analytics pipelines. Exactly-once would require:
1. Kafka transactional consumer (not supported by ClickHouse Kafka Engine)
2. Two-phase commit between Kafka offset and ClickHouse INSERT (not available)
3. Idempotent consumer with deduplication at write time (possible but adds latency)

ReplacingMergeTree provides eventual deduplication at read time, which is sufficient for analytics workloads where consistency at query time matters more than consistency at write time.

### ReplacingMergeTree Version Columns

| Table | Engine | Version Column | Notes |
|---|---|---|---|
| `bronze.pg_transactions_raw` | ReplacingMergeTree | `__source_ts_ms` (Int64) | Debezium source timestamp |
| `bronze.pg_users_raw` | ReplacingMergeTree | `__source_ts_ms` (Int64) | |
| `bronze.pg_merchants_raw` | ReplacingMergeTree | `__source_ts_ms` (Int64) | |
| `bronze.pg_repayments_raw` | ReplacingMergeTree | `__source_ts_ms` (Int64) | |
| `bronze.pg_installments_raw` | ReplacingMergeTree | `__source_ts_ms` (Int64) | |
| `silver.transactions_silver` | MergeTree | — | Immutable facts, no dedup needed |
| `silver.repayments_silver` | ReplacingMergeTree | `updated_at` (DateTime64) | Mutable state |
| `silver.users_silver` | ReplacingMergeTree | `_version` (UInt64) | Mutable state |
| `silver.merchants_silver` | ReplacingMergeTree | `_version` (UInt64) | Mutable state |
| `feature_store.user_credit_features` | ReplacingMergeTree | `snapshot_ts` (DateTime64) | Point-in-time features |

### Deduplication Strategy Summary

- **Bronze:** ReplacingMergeTree with `__source_ts_ms` version. Background merges deduplicate physically. Queries without FINAL may see duplicates.
- **Silver:** ReplacingMergeTree on mutable tables (`users`, `merchants`, `repayments`). dbt staging models query with `FINAL` for consistent reads. `transactions_silver` is MergeTree (immutable facts — no dedup needed).
- **Gold:** dbt marts query deduplicated staging models. `delete+insert` incremental strategy prevents double-counting.
- **Feature Store:** ReplacingMergeTree on `(user_id, valid_from)` with `snapshot_ts` version. FastAPI queries with `ORDER BY valid_from DESC LIMIT 1` (not FINAL).

### Implications for Data Quality

- Bronze row counts may exceed source row counts (duplicates from CDC replay)
- `unique` dbt tests on Bronze PKs would false-fail — Phase 7A intentionally omitted them (deviation D-1)
- Silver `relationships` tests use `severity: warn` because temporary FK mismatches may occur before background merge
- Cross-stage row count reconciliation must account for dedup: `SELECT count() FROM silver.X FINAL` vs `SELECT count() FROM bronze.X`
- Feature Store temporal queries (`as_of`) are correct because `valid_from`/`valid_to` temporal range + ORDER BY DESC LIMIT 1 returns the single latest version per user

## Consequences

- All dbt models on ReplacingMergeTree Silver tables MUST use `FINAL` in their source queries (enforced in staging layer)
- Bronze tables are intentionally not deduplicated at query time — they are the raw CDC event log
- The DQ framework (Phase 7A) accounts for this: Bronze tests use `not_null` only, Silver tests use `severity:warn` for FK relationships
- FastAPI does not use `FINAL` — acceptable because `ORDER BY valid_from DESC LIMIT 1` returns the correct latest row even with un-merged duplicates
- Schema drift detection (Phase 7B) monitors for Avro schema evolution that would add fields not present in ClickHouse Bronze tables

# ClickHouse DDL -- OrderFlow

## Bronze Layer Pattern

The bronze layer ingests CDC events from Kafka into ClickHouse using a three-object pattern per source table:

1. **Kafka Engine table** (`bronze.{source}_{table}_kafka`) -- connects to Kafka topic and deserializes messages. These tables do not store data; they act as a streaming source.
2. **Materialized View** (`bronze.mv_{source}_{table}`) -- reads from the Kafka Engine table and performs type conversions (String to Decimal, epoch millis to DateTime, ISO strings to DateTime). Writes results into the raw storage table.
3. **Raw MergeTree table** (`bronze.{source}_{table}_raw`) -- persistent storage. PostgreSQL tables use `ReplacingMergeTree` (keyed by primary ID, versioned by `__source_ts_ms`) to deduplicate CDC updates. MongoDB tables use plain `MergeTree` because events are insert-only.

## Naming Convention

| Object Type    | Pattern                            | Example                          |
|----------------|------------------------------------|----------------------------------|
| Kafka Engine   | `bronze.{source}_{table}_kafka`    | `bronze.pg_transactions_kafka`   |
| Raw Storage    | `bronze.{source}_{table}_raw`      | `bronze.pg_transactions_raw`     |
| Materialized View | `bronze.mv_{source}_{table}`    | `bronze.mv_pg_transactions`      |

Sources: `pg` (PostgreSQL via Debezium), `mongo` (MongoDB via Debezium).

## Apply Order

Execute files in numeric order. Dependencies require this sequence:

1. `01_create_databases.sql` -- databases must exist first
2. `02-08` -- Kafka Engine tables (no dependencies beyond database)
3. `09-15` -- Raw MergeTree storage tables (no dependencies beyond database)
4. `16-22` -- Materialized Views (depend on both the Kafka and raw tables)

## Key Type Conversions

| Source Type                | Bronze Raw Type    | Conversion Function               |
|----------------------------|--------------------|------------------------------------|
| String (decimal amount)    | Decimal64(2)       | `toDecimal64(amount, 2)`          |
| String (commission rate)   | Decimal64(4)       | `toDecimal64(commission_rate, 4)` |
| Int64 (epoch millis)       | DateTime64(3)      | `fromUnixTimestamp64Milli(...)`    |
| String (ISO timestamp)     | DateTime64(3)      | `parseDateTimeBestEffort(...)`     |
| String (date)              | Date               | `toDate(...)`                      |

## Format by Source

- **PostgreSQL** tables: `AvroConfluent` format with Schema Registry at `http://schema-registry.paystream.local:8081`
- **MongoDB** tables: `JSONEachRow` format (MongoDB connector uses JsonConverter)

## CDC Metadata Columns

All PostgreSQL bronze tables include Debezium metadata:
- `__op` -- operation type (c=create, u=update, d=delete, r=read/snapshot)
- `__source_ts_ms` -- source database timestamp in epoch milliseconds
- `_ingested_at` -- ClickHouse ingestion timestamp (DEFAULT now())

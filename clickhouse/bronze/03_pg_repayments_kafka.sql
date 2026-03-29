-- 03_pg_repayments_kafka.sql
-- Kafka Engine table consuming Debezium CDC events from PostgreSQL repayments table.
-- Format: AvroConfluent (Schema Registry). Columns match ExtractNewRecordState output.
-- due_date arrives as String from Debezium. paid_at is Nullable epoch millis.

CREATE TABLE IF NOT EXISTS bronze.pg_repayments_kafka
(
    repayment_id        Int64,
    transaction_id      Int64,
    user_id             Int64,
    installment_number  Int16,
    amount              String,
    due_date            String,
    paid_at             Nullable(Int64),
    status              String,
    created_at          Int64,
    updated_at          Int64,
    __op                String,
    __source_ts_ms      Int64
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'BOOTSTRAP_BROKERS_SCRAM',
    kafka_topic_list = 'paystream.public.repayments',
    kafka_group_name = 'clickhouse_bronze_repayments',
    kafka_format = 'AvroConfluent',
    format_avro_schema_registry_url = 'http://schema-registry.paystream.local:8081';

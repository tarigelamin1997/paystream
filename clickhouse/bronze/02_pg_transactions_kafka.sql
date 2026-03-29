-- 02_pg_transactions_kafka.sql
-- Kafka Engine table consuming Debezium CDC events from PostgreSQL transactions table.
-- Format: AvroConfluent (Schema Registry). Columns match ExtractNewRecordState output.
-- decimal.handling.mode=string means amount arrives as String.
-- created_at is epoch millis (Int64) from Debezium.

CREATE TABLE IF NOT EXISTS bronze.pg_transactions_kafka
(
    transaction_id      Int64,
    user_id             Int64,
    merchant_id         Int32,
    amount              String,
    currency            String,
    status              String,
    decision_latency_ms Nullable(Int16),
    installment_count   Int16,
    created_at          Int64,
    __op                String,
    __source_ts_ms      Int64
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'BOOTSTRAP_BROKERS_SCRAM',
    kafka_topic_list = 'paystream.public.transactions',
    kafka_group_name = 'clickhouse_bronze_transactions',
    kafka_format = 'AvroConfluent',
    format_avro_schema_registry_url = 'http://schema-registry.paystream.local:8081';

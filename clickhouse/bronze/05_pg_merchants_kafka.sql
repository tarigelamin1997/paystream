-- 05_pg_merchants_kafka.sql
-- Kafka Engine table consuming Debezium CDC events from PostgreSQL merchants table.
-- Format: AvroConfluent (Schema Registry). Columns match ExtractNewRecordState output.
-- commission_rate and credit_limit arrive as String (decimal.handling.mode=string).

CREATE TABLE IF NOT EXISTS bronze.pg_merchants_kafka
(
    merchant_id         Int32,
    merchant_name       String,
    merchant_category   String,
    risk_tier           String,
    commission_rate     String,
    credit_limit        String,
    country             String,
    created_at          Int64,
    updated_at          Int64,
    __op                String,
    __source_ts_ms      Int64
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'BOOTSTRAP_BROKERS_SCRAM',
    kafka_topic_list = 'paystream.public.merchants',
    kafka_group_name = 'clickhouse_bronze_merchants',
    kafka_format = 'AvroConfluent',
    format_avro_schema_registry_url = 'http://schema-registry.paystream.local:8081';

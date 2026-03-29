-- 04_pg_users_kafka.sql
-- Kafka Engine table consuming Debezium CDC events from PostgreSQL users table.
-- Format: AvroConfluent (Schema Registry). Columns match ExtractNewRecordState output.
-- national_id is masked by Debezium MaskField SMT (arrives as asterisks).
-- credit_limit arrives as String (decimal.handling.mode=string).

CREATE TABLE IF NOT EXISTS bronze.pg_users_kafka
(
    user_id             Int64,
    full_name           String,
    email               String,
    phone               Nullable(String),
    national_id         Nullable(String),
    credit_limit        String,
    credit_tier         String,
    kyc_status          String,
    created_at          Int64,
    updated_at          Int64,
    __op                String,
    __source_ts_ms      Int64
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'BOOTSTRAP_BROKERS_SCRAM',
    kafka_topic_list = 'paystream.public.users',
    kafka_group_name = 'clickhouse_bronze_users',
    kafka_format = 'AvroConfluent',
    format_avro_schema_registry_url = 'http://schema-registry.paystream.local:8081';

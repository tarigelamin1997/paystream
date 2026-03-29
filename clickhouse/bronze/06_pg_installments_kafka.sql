-- 06_pg_installments_kafka.sql
-- Kafka Engine table consuming Debezium CDC events from PostgreSQL installments table.
-- Format: AvroConfluent (Schema Registry). Columns match ExtractNewRecordState output.
-- total_amount and installment_amount arrive as String (decimal.handling.mode=string).
-- start_date and end_date arrive as String from Debezium.

CREATE TABLE IF NOT EXISTS bronze.pg_installments_kafka
(
    schedule_id         Int64,
    transaction_id      Int64,
    user_id             Int64,
    total_amount        String,
    installment_count   Int16,
    installment_amount  String,
    start_date          String,
    end_date            String,
    status              String,
    created_at          Int64,
    __op                String,
    __source_ts_ms      Int64
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'BOOTSTRAP_BROKERS_SCRAM',
    kafka_topic_list = 'paystream.public.installments',
    kafka_group_name = 'clickhouse_bronze_installments',
    kafka_format = 'AvroConfluent',
    format_avro_schema_registry_url = 'http://schema-registry.paystream.local:8081';

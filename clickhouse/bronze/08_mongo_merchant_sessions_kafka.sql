-- 08_mongo_merchant_sessions_kafka.sql
-- Kafka Engine table consuming MongoDB CDC events from merchant_sessions collection.
-- Format: JSONEachRow (MongoDB connector uses JsonConverter, not Avro).
-- created_at is an ISO timestamp string from MongoDB.

CREATE TABLE IF NOT EXISTS bronze.mongo_merchant_sessions_kafka
(
    session_id          String,
    merchant_id         String,
    action              String,
    page                Nullable(String),
    duration_seconds    Nullable(Int32),
    created_at          String
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'BOOTSTRAP_BROKERS_SCRAM',
    kafka_topic_list = 'paystream.mongo.merchant_sessions',
    kafka_group_name = 'clickhouse_bronze_merchant_sessions',
    kafka_format = 'JSONEachRow';

-- 07_mongo_app_events_kafka.sql
-- Kafka Engine table consuming MongoDB CDC events from app_events collection.
-- Format: JSONEachRow (MongoDB connector uses JsonConverter, not Avro).
-- created_at is an ISO timestamp string from MongoDB.

CREATE TABLE IF NOT EXISTS bronze.mongo_app_events_kafka
(
    event_id    String,
    user_id     String,
    event_type  String,
    merchant_id Nullable(String),
    session_id  String,
    device_type String,
    event_data  String,
    created_at  String
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'BOOTSTRAP_BROKERS_SCRAM',
    kafka_topic_list = 'paystream.mongo.app_events',
    kafka_group_name = 'clickhouse_bronze_app_events',
    kafka_format = 'JSONEachRow';

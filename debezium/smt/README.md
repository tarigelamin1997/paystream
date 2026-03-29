# PayStream — SMT (Single Message Transform) Chains

## PostgreSQL Connector SMT Chain

1. **ExtractNewRecordState** (`io.debezium.transforms.ExtractNewRecordState`)
   - Flattens the Debezium change event envelope into a simple key/value record.
   - Adds metadata fields: `__op` (operation type) and `__source_ts_ms` (source timestamp).
   - Delete handling mode: `rewrite` — deleted records are emitted with a `__deleted` field set to `true`.
   - Tombstone records are dropped.

2. **MaskField** (`org.apache.kafka.connect.transforms.MaskField$Value`)
   - PII scrub on the `national_id` field.
   - Replaces the value with `********` before the record reaches Kafka.

## MongoDB Connector SMT Chain

1. **ExtractNewDocumentState** (`io.debezium.connector.mongodb.transforms.ExtractNewDocumentState`)
   - Flattens the MongoDB change event envelope (which wraps the document in an `after` field) into a simple JSON record.
   - Adds metadata fields: `__op` (operation type) and `__source_ts_ms` (source timestamp).
   - Delete handling mode: `rewrite` — deleted documents are emitted with a `__deleted` field set to `true`.
   - Tombstone records are dropped.

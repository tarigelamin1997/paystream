#!/bin/bash
set -euo pipefail
# Create DLQ topic via Kafka AdminClient
# MSK Serverless auto-creates data topics on first produce by Debezium
# This script creates the DLQ topic which is not auto-created

BOOTSTRAP_BROKERS="${1:?Usage: create_topics.sh <bootstrap-brokers>}"

echo "Creating DLQ topic..."
python3 -c "
from kafka.admin import KafkaAdminClient, NewTopic
import ssl

admin = KafkaAdminClient(
    bootstrap_servers='${BOOTSTRAP_BROKERS}',
    security_protocol='SASL_SSL',
    sasl_mechanism='AWS_MSK_IAM',
    client_id='paystream-topic-admin'
)

topics = [NewTopic(name='paystream.dlq', num_partitions=1, replication_factor=1)]
admin.create_topics(new_topics=topics)
print('DLQ topic created.')
"

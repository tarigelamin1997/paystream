# MSK Provisioned — topics auto-created by Debezium on first connection.
# Topics are created by Debezium on first connection:
#   - paystream.public.users (1 partition)
#   - paystream.public.merchants (1 partition)
#   - paystream.public.transactions (3 partitions)
#   - paystream.public.repayments (3 partitions)
#   - paystream.public.installment_schedules (1 partition)
#   - paystream.mongo.app_events (3 partitions)
#   - paystream.mongo.merchant_sessions (1 partition)
#   - paystream.dlq (1 partition)
#
# DLQ topic is created via scripts/create_topics.sh using AdminClient.
# Partition counts are configured in Debezium connector configs.

# PayStream — Dev Environment (cost-optimized, single-AZ)
environment          = "dev"
aws_region           = "eu-north-1"
aws_profile          = "orderflow"
project_name         = "paystream"

# VPC
vpc_cidr               = "10.0.0.0/16"
public_subnet_cidr     = "10.0.1.0/24"
private_subnet_cidr    = "10.0.10.0/24"
private_subnet_1b_cidr = "10.0.11.0/24"
az_primary             = "eu-north-1a"
az_secondary           = "eu-north-1b"

# Bastion
bastion_allowed_cidr = "0.0.0.0/0"  # Replace with your IP: x.x.x.x/32
bastion_key_name     = "paystream-bastion"
bastion_instance_type = "t3.micro"

# RDS
rds_instance_class    = "db.t3.medium"
rds_allocated_storage = 50
rds_master_username   = "paystream_admin"

# DocumentDB
documentdb_instance_class = "db.t3.medium"

# ClickHouse
clickhouse_instance_type = "r6i.large"
clickhouse_ebs_size      = 100

# ECS
debezium_pg_cpu       = 1024
debezium_pg_memory    = 2048
debezium_mongo_cpu    = 512
debezium_mongo_memory = 1024
schema_registry_cpu   = 512
schema_registry_memory = 1024

# MWAA
mwaa_environment_class = "mw1.small"

# Alerting (Phase 7C)
alert_email       = "tarigelamin1997@gmail.com"
slack_webhook_url = ""

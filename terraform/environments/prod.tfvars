# PayStream — Production Environment (not used for portfolio)
environment          = "prod"
aws_region           = "eu-north-1"
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

# RDS — production-grade sizing
rds_instance_class    = "db.r6g.large"
rds_allocated_storage = 100
rds_master_username   = "paystream_admin"

# DocumentDB — production-grade sizing
documentdb_instance_class = "db.r6g.large"

# ClickHouse
clickhouse_instance_type = "r6i.xlarge"
clickhouse_ebs_size      = 500

# ECS
debezium_pg_cpu       = 2048
debezium_pg_memory    = 4096
debezium_mongo_cpu    = 1024
debezium_mongo_memory = 2048
schema_registry_cpu   = 1024
schema_registry_memory = 2048

# MWAA
mwaa_environment_class = "mw1.medium"

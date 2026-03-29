variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "paystream"
}

# VPC
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR (eu-north-1a)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR (eu-north-1a)"
  type        = string
  default     = "10.0.10.0/24"
}

variable "private_subnet_1b_cidr" {
  description = "Private subnet CIDR (eu-north-1b, MWAA only)"
  type        = string
  default     = "10.0.11.0/24"
}

variable "az_primary" {
  description = "Primary availability zone"
  type        = string
  default     = "eu-north-1a"
}

variable "az_secondary" {
  description = "Secondary availability zone (MWAA only)"
  type        = string
  default     = "eu-north-1b"
}

# Bastion
variable "bastion_allowed_cidr" {
  description = "CIDR allowed to SSH to bastion"
  type        = string
}

variable "bastion_key_name" {
  description = "SSH key pair name for bastion"
  type        = string
  default     = "paystream-bastion"
}

# RDS
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_master_username" {
  description = "RDS master username"
  type        = string
  default     = "paystream_admin"
}

# DocumentDB
variable "documentdb_instance_class" {
  description = "DocumentDB instance class"
  type        = string
  default     = "db.t3.medium"
}

# ClickHouse
variable "clickhouse_instance_type" {
  description = "ClickHouse EC2 instance type"
  type        = string
  default     = "r6i.large"
}

variable "clickhouse_ebs_size" {
  description = "ClickHouse EBS volume size in GB"
  type        = number
  default     = 100
}

# ECS
variable "debezium_pg_cpu" {
  description = "Debezium PG task CPU units"
  type        = number
  default     = 1024
}

variable "debezium_pg_memory" {
  description = "Debezium PG task memory in MB"
  type        = number
  default     = 2048
}

variable "debezium_mongo_cpu" {
  description = "Debezium Mongo task CPU units"
  type        = number
  default     = 512
}

variable "debezium_mongo_memory" {
  description = "Debezium Mongo task memory in MB"
  type        = number
  default     = 1024
}

variable "schema_registry_cpu" {
  description = "Schema Registry task CPU units"
  type        = number
  default     = 512
}

variable "schema_registry_memory" {
  description = "Schema Registry task memory in MB"
  type        = number
  default     = 1024
}

# Bastion
variable "bastion_instance_type" {
  description = "Bastion EC2 instance type"
  type        = string
  default     = "t3.micro"
}

# MWAA
variable "mwaa_environment_class" {
  description = "MWAA environment class"
  type        = string
  default     = "mw1.small"
}

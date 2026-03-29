variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_sg_ids" {
  type = list(string)
}

variable "msk_bootstrap_brokers" {
  type = string
}

variable "rds_endpoint" {
  type = string
}

variable "rds_db_name" {
  type = string
}

variable "rds_secret_arn" {
  type = string
}

variable "documentdb_endpoint" {
  type = string
}

variable "documentdb_secret_arn" {
  type = string
}

variable "debezium_pg_cpu" {
  type = number
}

variable "debezium_pg_memory" {
  type = number
}

variable "debezium_mongo_cpu" {
  type = number
}

variable "debezium_mongo_memory" {
  type = number
}

variable "schema_registry_cpu" {
  type = number
}

variable "schema_registry_memory" {
  type = number
}

variable "debezium_pg_role_arn" {
  type = string
}

variable "debezium_mongo_role_arn" {
  type = string
}

variable "schema_registry_role_arn" {
  type = string
}

variable "ecs_execution_role_arn" {
  type = string
}

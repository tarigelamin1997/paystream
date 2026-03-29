# VPC
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# RDS
output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds.endpoint
}

# DocumentDB
output "documentdb_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = module.documentdb.cluster_endpoint
}

# MSK
output "msk_bootstrap_brokers_iam" {
  description = "MSK bootstrap brokers (IAM auth)"
  value       = module.msk.bootstrap_brokers_iam
}

output "msk_bootstrap_brokers_scram" {
  description = "MSK bootstrap brokers (SCRAM auth)"
  value       = module.msk.bootstrap_brokers_scram
}

output "msk_cluster_arn" {
  description = "MSK cluster ARN"
  value       = module.msk.cluster_arn
}

# ClickHouse
output "clickhouse_private_ip" {
  description = "ClickHouse EC2 private IP"
  value       = module.clickhouse.private_ip
}

# ECS
output "schema_registry_url" {
  description = "Schema Registry service discovery URL"
  value       = module.ecs.schema_registry_url
}

# FastAPI (Phase 5)
output "alb_dns_name" {
  description = "FastAPI ALB DNS name"
  value       = module.ecs.alb_dns_name
}

output "fastapi_ecr_url" {
  description = "FastAPI ECR repository URL"
  value       = module.ecs.fastapi_ecr_url
}

# S3
output "s3_bucket_names" {
  description = "S3 bucket names"
  value       = module.s3.bucket_names
}

# EMR
output "emr_application_id" {
  description = "EMR Serverless application ID"
  value       = module.emr.application_id
}

# MWAA
output "mwaa_webserver_url" {
  description = "MWAA webserver URL"
  value       = module.mwaa.webserver_url
}

# Observability
output "grafana_endpoint" {
  description = "Amazon Managed Grafana endpoint"
  value       = module.observability.grafana_endpoint
}

output "prometheus_endpoint" {
  description = "Amazon Managed Prometheus endpoint"
  value       = module.observability.prometheus_endpoint
}

# Bastion
output "bastion_public_ip" {
  description = "Bastion host Elastic IP"
  value       = module.bastion.public_ip
}

output "bastion_private_key" {
  description = "Bastion SSH private key (sensitive)"
  value       = module.bastion.private_key_pem
  sensitive   = true
}

output "cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "schema_registry_url" {
  description = "Schema Registry service discovery URL"
  value       = "http://schema-registry.${var.project_name}.local:8081"
}

output "debezium_pg_service_arn" {
  value = aws_ecs_service.debezium_pg.id
}

output "debezium_mongo_service_arn" {
  value = aws_ecs_service.debezium_mongo.id
}

output "debezium_pg_ecr_url" {
  value = aws_ecr_repository.debezium_pg.repository_url
}

output "debezium_mongo_ecr_url" {
  value = aws_ecr_repository.debezium_mongo.repository_url
}

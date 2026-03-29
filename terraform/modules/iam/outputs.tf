output "ecs_execution_role_arn" {
  value = aws_iam_role.ecs_execution.arn
}

output "ecs_debezium_pg_role_arn" {
  value = aws_iam_role.ecs_debezium_pg.arn
}

output "ecs_debezium_mongo_role_arn" {
  value = aws_iam_role.ecs_debezium_mongo.arn
}

output "ecs_schema_registry_role_arn" {
  value = aws_iam_role.ecs_schema_registry.arn
}

output "emr_execution_role_arn" {
  value = aws_iam_role.emr_execution.arn
}

output "mwaa_execution_role_arn" {
  value = aws_iam_role.mwaa_execution.arn
}

output "ecs_fastapi_role_arn" {
  value = aws_iam_role.ecs_fastapi.arn
}

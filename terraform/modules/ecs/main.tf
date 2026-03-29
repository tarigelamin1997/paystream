data "aws_caller_identity" "current" {}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-ecs"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-ecs"
  }
}

resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "${var.project_name}.local"
  vpc  = var.vpc_id

  tags = {
    Name = "${var.project_name}-service-discovery"
  }
}

resource "aws_ecr_repository" "debezium_pg" {
  name                 = "${var.project_name}-debezium-pg"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Name = "${var.project_name}-debezium-pg"
  }
}

resource "aws_ecr_repository" "debezium_mongo" {
  name                 = "${var.project_name}-debezium-mongo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Name = "${var.project_name}-debezium-mongo"
  }
}

resource "aws_cloudwatch_log_group" "debezium_pg" {
  name              = "/ecs/${var.project_name}/debezium-pg"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-debezium-pg-logs"
  }
}

resource "aws_cloudwatch_log_group" "debezium_mongo" {
  name              = "/ecs/${var.project_name}/debezium-mongo"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-debezium-mongo-logs"
  }
}

resource "aws_cloudwatch_log_group" "schema_registry" {
  name              = "/ecs/${var.project_name}/schema-registry"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-schema-registry-logs"
  }
}

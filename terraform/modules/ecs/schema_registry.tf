resource "aws_service_discovery_service" "schema_registry" {
  name = "schema-registry"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "schema_registry" {
  family                   = "${var.project_name}-schema-registry"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.schema_registry_cpu
  memory                   = var.schema_registry_memory
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.schema_registry_role_arn

  container_definitions = jsonencode([
    {
      name  = "schema-registry"
      image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/paystream-schema-registry:7.6.1"
      portMappings = [
        {
          containerPort = 8081
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "SCHEMA_REGISTRY_HOST_NAME"
          value = "0.0.0.0"
        },
        {
          name  = "SCHEMA_REGISTRY_LISTENERS"
          value = "http://0.0.0.0:8081"
        },
        {
          name  = "SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS"
          value = var.msk_bootstrap_brokers
        },
        {
          name  = "SCHEMA_REGISTRY_KAFKASTORE_SECURITY_PROTOCOL"
          value = "SASL_SSL"
        },
        {
          name  = "SCHEMA_REGISTRY_KAFKASTORE_SASL_MECHANISM"
          value = "AWS_MSK_IAM"
        },
        {
          name  = "SCHEMA_REGISTRY_KAFKASTORE_SASL_JAAS_CONFIG"
          value = "software.amazon.msk.auth.iam.IAMLoginModule required;"
        },
        {
          name  = "SCHEMA_REGISTRY_KAFKASTORE_SASL_CLIENT_CALLBACK_HANDLER_CLASS"
          value = "software.amazon.msk.auth.iam.IAMClientCallbackHandler"
        },
        {
          name  = "CLASSPATH"
          value = "/usr/share/java/schema-registry/*:/usr/share/java/cp-base-new/*"
        },
        {
          name  = "CUB_CLASSPATH"
          value = "/usr/share/java/schema-registry/*:/usr/share/java/confluent-security/schema-registry/*:/usr/share/java/cp-base-new/*"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}/schema-registry"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "schema-registry"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-schema-registry"
  }
}

resource "aws_ecs_service" "schema_registry" {
  name            = "${var.project_name}-schema-registry"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.schema_registry.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = var.ecs_sg_ids
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.schema_registry.arn
  }

  tags = {
    Name = "${var.project_name}-schema-registry"
  }
}

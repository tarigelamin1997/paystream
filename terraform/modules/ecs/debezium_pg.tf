resource "aws_ecs_task_definition" "debezium_pg" {
  family                   = "${var.project_name}-debezium-pg"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.debezium_pg_cpu
  memory                   = var.debezium_pg_memory
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.debezium_pg_role_arn

  container_definitions = jsonencode([
    {
      name  = "debezium-pg"
      image = "${aws_ecr_repository.debezium_pg.repository_url}:latest"
      portMappings = [
        {
          containerPort = 8083
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "BOOTSTRAP_SERVERS"
          value = var.msk_bootstrap_brokers
        },
        {
          name  = "GROUP_ID"
          value = "${var.project_name}-debezium-pg"
        },
        {
          name  = "CONFIG_STORAGE_TOPIC"
          value = "${var.project_name}.debezium.pg.configs"
        },
        {
          name  = "OFFSET_STORAGE_TOPIC"
          value = "${var.project_name}.debezium.pg.offsets"
        },
        {
          name  = "STATUS_STORAGE_TOPIC"
          value = "${var.project_name}.debezium.pg.status"
        },
        {
          name  = "CONNECT_SECURITY_PROTOCOL"
          value = "SASL_SSL"
        },
        {
          name  = "CONNECT_SASL_MECHANISM"
          value = "AWS_MSK_IAM"
        },
        {
          name  = "CONNECT_SASL_JAAS_CONFIG"
          value = "software.amazon.msk.auth.iam.IAMLoginModule required;"
        },
        {
          name  = "CONNECT_SASL_CLIENT_CALLBACK_HANDLER_CLASS"
          value = "software.amazon.msk.auth.iam.IAMClientCallbackHandler"
        },
        {
          name  = "CONNECT_PRODUCER_SECURITY_PROTOCOL"
          value = "SASL_SSL"
        },
        {
          name  = "CONNECT_PRODUCER_SASL_MECHANISM"
          value = "AWS_MSK_IAM"
        },
        {
          name  = "CONNECT_PRODUCER_SASL_JAAS_CONFIG"
          value = "software.amazon.msk.auth.iam.IAMLoginModule required;"
        },
        {
          name  = "CONNECT_PRODUCER_SASL_CLIENT_CALLBACK_HANDLER_CLASS"
          value = "software.amazon.msk.auth.iam.IAMClientCallbackHandler"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}/debezium-pg"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "debezium-pg"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-debezium-pg"
  }
}

resource "aws_ecs_service" "debezium_pg" {
  name            = "${var.project_name}-debezium-pg"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.debezium_pg.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = var.ecs_sg_ids
    assign_public_ip = false
  }

  tags = {
    Name = "${var.project_name}-debezium-pg"
  }
}

resource "aws_ecs_task_definition" "debezium_mongo" {
  family                   = "${var.project_name}-debezium-mongo"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.debezium_mongo_cpu
  memory                   = var.debezium_mongo_memory
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.debezium_mongo_role_arn

  container_definitions = jsonencode([
    {
      name  = "debezium-mongo"
      image = "${aws_ecr_repository.debezium_mongo.repository_url}:latest"
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
          value = "${var.project_name}-debezium-mongo"
        },
        {
          name  = "CONFIG_STORAGE_TOPIC"
          value = "${var.project_name}.debezium.mongo.configs"
        },
        {
          name  = "OFFSET_STORAGE_TOPIC"
          value = "${var.project_name}.debezium.mongo.offsets"
        },
        {
          name  = "STATUS_STORAGE_TOPIC"
          value = "${var.project_name}.debezium.mongo.status"
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
          "awslogs-group"         = "/ecs/${var.project_name}/debezium-mongo"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "debezium-mongo"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-debezium-mongo"
  }
}

resource "aws_ecs_service" "debezium_mongo" {
  name            = "${var.project_name}-debezium-mongo"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.debezium_mongo.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = var.ecs_sg_ids
    assign_public_ip = false
  }

  tags = {
    Name = "${var.project_name}-debezium-mongo"
  }
}

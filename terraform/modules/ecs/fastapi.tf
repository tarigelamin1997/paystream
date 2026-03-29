# Phase 5 — FastAPI Feature Store API on ECS Fargate + ALB

# --- ECR Repository ---
resource "aws_ecr_repository" "fastapi" {
  name                 = "${var.project_name}-fastapi"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Name = "${var.project_name}-fastapi"
  }
}

# --- CloudWatch Log Group ---
resource "aws_cloudwatch_log_group" "fastapi" {
  name              = "/ecs/${var.project_name}-fastapi"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-fastapi-logs"
  }
}

# --- ALB Security Group (public, TCP 80) ---
resource "aws_security_group" "fastapi_alb" {
  name_prefix = "${var.project_name}-alb-"
  description = "FastAPI ALB - public HTTP"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# --- ECS Security Group rule: allow ALB → FastAPI 8000 ---
resource "aws_security_group_rule" "alb_to_fastapi" {
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.fastapi_alb.id
  security_group_id        = var.ecs_sg_ids[0]
  description              = "ALB to FastAPI container"
}

# --- ECS Task Definition ---
resource "aws_ecs_task_definition" "fastapi" {
  family                   = "${var.project_name}-fastapi"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.fastapi_task_role_arn

  container_definitions = jsonencode([{
    name  = "fastapi"
    image = "${aws_ecr_repository.fastapi.repository_url}:latest"
    portMappings = [{ containerPort = 8000, protocol = "tcp" }]
    environment = [
      { name = "CLICKHOUSE_HOST", value = var.clickhouse_private_ip },
      { name = "CLICKHOUSE_PORT", value = "9000" },
      { name = "FEATURE_VERSION", value = "v2.1.0" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.fastapi.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "fastapi"
      }
    }
  }])

  tags = {
    Name = "${var.project_name}-fastapi-task"
  }
}

# --- Application Load Balancer (internet-facing) ---
resource "aws_lb" "fastapi" {
  name               = "${var.project_name}-fastapi-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.fastapi_alb.id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "${var.project_name}-fastapi-alb"
  }
}

# --- Target Group ---
resource "aws_lb_target_group" "fastapi" {
  name        = "${var.project_name}-fastapi-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    Name = "${var.project_name}-fastapi-tg"
  }
}

# --- ALB Listener ---
resource "aws_lb_listener" "fastapi" {
  load_balancer_arn = aws_lb.fastapi.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fastapi.arn
  }
}

# --- ECS Service ---
resource "aws_ecs_service" "fastapi" {
  name            = "${var.project_name}-fastapi"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.fastapi.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.private_subnet_ids[0]]
    security_groups  = var.ecs_sg_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.fastapi.arn
    container_name   = "fastapi"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.fastapi]

  tags = {
    Name = "${var.project_name}-fastapi-service"
  }
}

# --- Outputs ---
output "alb_dns_name" {
  description = "FastAPI ALB DNS name"
  value       = aws_lb.fastapi.dns_name
}

output "fastapi_ecr_url" {
  description = "FastAPI ECR repository URL"
  value       = aws_ecr_repository.fastapi.repository_url
}

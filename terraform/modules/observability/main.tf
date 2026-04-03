# Amazon Managed Prometheus — available in eu-north-1
resource "aws_prometheus_workspace" "main" {
  alias = "${var.project_name}-prometheus"

  tags = {
    Name = "${var.project_name}-prometheus"
  }
}

# Amazon Managed Grafana — NOT available in eu-north-1
# AMG will need to be provisioned in a supported region (e.g., eu-west-1)
# or accessed via self-hosted Grafana on ECS. Deferred to Phase 6.
# resource "aws_grafana_workspace" "main" { ... }

# --- SNS Alerting Topic (Phase 7C) ---

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name    = "${var.project_name}-alerts"
    Project = var.project_name
    Phase   = "7c"
  }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "slack_alerts" {
  count     = var.slack_webhook_url != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "https"
  endpoint  = var.slack_webhook_url
}

# --- CloudWatch RDS Storage Alarm (Phase 7C) ---

resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "${var.project_name}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120 # 5 GB in bytes
  alarm_description   = "PayStream RDS free storage below 5 GB — risk of WAL accumulation blocking Debezium"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_identifier
  }

  tags = {
    Name    = "${var.project_name}-rds-storage-low"
    Project = var.project_name
    Phase   = "7c"
  }
}

# --- Lambda + API Gateway: Grafana → SNS Bridge (Phase 7C) ---

resource "aws_iam_role" "grafana_sns_lambda" {
  name = "${var.project_name}-grafana-sns-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "grafana_sns_lambda" {
  name = "${var.project_name}-grafana-sns-publish"
  role = aws_iam_role.grafana_sns_lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [aws_sns_topic.alerts.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}

data "archive_file" "grafana_sns_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/grafana_to_sns.py"
  output_path = "${path.module}/lambda/grafana_to_sns.zip"
}

resource "aws_lambda_function" "grafana_sns" {
  filename         = data.archive_file.grafana_sns_lambda.output_path
  source_code_hash = data.archive_file.grafana_sns_lambda.output_base64sha256
  function_name    = "${var.project_name}-grafana-sns-bridge"
  role             = aws_iam_role.grafana_sns_lambda.arn
  handler          = "grafana_to_sns.handler"
  runtime          = "python3.12"
  timeout          = 10

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }

  tags = {
    Project = var.project_name
    Phase   = "7c"
  }
}

resource "aws_apigatewayv2_api" "grafana_webhook" {
  name          = "${var.project_name}-grafana-webhook"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "grafana_lambda" {
  api_id                 = aws_apigatewayv2_api.grafana_webhook.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.grafana_sns.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "grafana_webhook" {
  api_id    = aws_apigatewayv2_api.grafana_webhook.id
  route_key = "POST /"
  target    = "integrations/${aws_apigatewayv2_integration.grafana_lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.grafana_webhook.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.grafana_sns.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.grafana_webhook.execution_arn}/*/*"
}

resource "aws_iam_role" "grafana" {
  name = "${var.project_name}-grafana-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "grafana.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-grafana-role"
  }
}

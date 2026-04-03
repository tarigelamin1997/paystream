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

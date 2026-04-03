output "grafana_endpoint" {
  description = "AMG not available in eu-north-1 — deferred to Phase 6"
  value       = "N/A — AMG not available in eu-north-1"
}

output "prometheus_endpoint" {
  value = aws_prometheus_workspace.main.prometheus_endpoint
}

output "sns_topic_arn" {
  description = "ARN of the PayStream alerts SNS topic"
  value       = aws_sns_topic.alerts.arn
}

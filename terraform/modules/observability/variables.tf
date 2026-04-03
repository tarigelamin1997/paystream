variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
  default     = ""
}

variable "slack_webhook_url" {
  description = "Slack incoming webhook URL for alert notifications. Leave empty to skip."
  type        = string
  default     = ""
  sensitive   = true
}

variable "rds_instance_identifier" {
  description = "RDS instance identifier for CloudWatch alarms"
  type        = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "environment_class" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "dags_bucket_arn" {
  type = string
}

variable "dags_bucket_name" {
  type = string
}

variable "mwaa_execution_role_arn" {
  type = string
}

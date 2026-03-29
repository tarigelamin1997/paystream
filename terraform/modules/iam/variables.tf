variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "msk_cluster_arn" {
  type = string
}

variable "s3_bucket_arns" {
  type = list(string)
}

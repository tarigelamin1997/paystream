variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidr" {
  type = string
}

variable "private_subnet_cidr" {
  type = string
}

variable "private_subnet_1b_cidr" {
  type = string
}

variable "az_primary" {
  type = string
}

variable "az_secondary" {
  type = string
}

variable "bastion_allowed_cidr" {
  type = string
}

# S3 backend for state (optional — local for dev)
# Uncomment for remote state:
# terraform {
#   backend "s3" {
#     bucket         = "paystream-terraform-state"
#     key            = "phase1/terraform.tfstate"
#     region         = "eu-north-1"
#     encrypt        = true
#     dynamodb_table = "paystream-terraform-locks"
#   }
# }

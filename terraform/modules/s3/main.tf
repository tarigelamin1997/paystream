locals {
  bucket_names = [
    "${var.project_name}-bronze-${var.environment}",
    "${var.project_name}-silver-${var.environment}",
    "${var.project_name}-gold-${var.environment}",
    "${var.project_name}-features-${var.environment}",
    "${var.project_name}-delta-${var.environment}",
    "${var.project_name}-mwaa-dags-${var.environment}",
  ]
}

resource "aws_s3_bucket" "buckets" {
  count  = length(local.bucket_names)
  bucket = local.bucket_names[count.index]
  force_destroy = true

  tags = {
    Name = local.bucket_names[count.index]
  }
}

resource "aws_s3_bucket_versioning" "buckets" {
  count  = length(local.bucket_names)
  bucket = aws_s3_bucket.buckets[count.index].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "buckets" {
  count  = length(local.bucket_names)
  bucket = aws_s3_bucket.buckets[count.index].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "buckets" {
  count  = length(local.bucket_names)
  bucket = aws_s3_bucket.buckets[count.index].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload placeholder requirements.txt for MWAA
resource "aws_s3_object" "mwaa_requirements" {
  bucket  = aws_s3_bucket.buckets[5].id
  key     = "requirements.txt"
  content = "# MWAA requirements - populated in Phase 5\n"
}

# Upload placeholder DAGs folder
resource "aws_s3_object" "mwaa_dags_placeholder" {
  bucket  = aws_s3_bucket.buckets[5].id
  key     = "dags/.gitkeep"
  content = ""
}

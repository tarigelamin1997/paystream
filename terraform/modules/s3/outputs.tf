output "bucket_names" {
  value = aws_s3_bucket.buckets[*].id
}

output "bucket_arns" {
  value = aws_s3_bucket.buckets[*].arn
}

output "mwaa_dags_bucket_arn" {
  value = aws_s3_bucket.buckets[5].arn
}

output "mwaa_dags_bucket_name" {
  value = aws_s3_bucket.buckets[5].id
}

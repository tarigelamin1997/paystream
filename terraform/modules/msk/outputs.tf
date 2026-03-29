output "bootstrap_brokers_iam" {
  description = "MSK bootstrap brokers (IAM auth, port 9098)"
  value       = aws_msk_cluster.main.bootstrap_brokers_sasl_iam
}

output "bootstrap_brokers_scram" {
  description = "MSK bootstrap brokers (SCRAM-SHA-512, port 9096)"
  value       = aws_msk_cluster.main.bootstrap_brokers_sasl_scram
}

output "cluster_arn" {
  description = "MSK cluster ARN"
  value       = aws_msk_cluster.main.arn
}

output "scram_secret_arn" {
  description = "SCRAM secret ARN for ClickHouse"
  value       = aws_secretsmanager_secret.msk_scram.arn
}

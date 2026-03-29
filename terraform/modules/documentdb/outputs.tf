output "cluster_endpoint" {
  value = aws_docdb_cluster.main.endpoint
}

output "port" {
  value = aws_docdb_cluster.main.port
}

output "master_secret_arn" {
  value = aws_secretsmanager_secret.docdb_master.arn
}

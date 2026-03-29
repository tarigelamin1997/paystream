output "private_ip" {
  value = aws_instance.clickhouse.private_ip
}

output "instance_id" {
  value = aws_instance.clickhouse.id
}

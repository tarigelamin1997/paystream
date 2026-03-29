output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public_1a.id
}

output "private_subnet_id" {
  value = aws_subnet.private_1a.id
}

output "private_subnet_1b_id" {
  value = aws_subnet.private_1b.id
}

output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "docdb_sg_id" {
  value = aws_security_group.docdb.id
}

output "msk_sg_id" {
  value = aws_security_group.msk.id
}

output "clickhouse_sg_id" {
  value = aws_security_group.clickhouse.id
}

output "ecs_sg_id" {
  value = aws_security_group.ecs.id
}

output "private_sg_id" {
  value = aws_security_group.private.id
}

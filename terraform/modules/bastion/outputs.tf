output "public_ip" {
  value = aws_eip.bastion.public_ip
}

output "instance_id" {
  value = aws_instance.bastion.id
}

output "private_key_pem" {
  value     = tls_private_key.bastion.private_key_pem
  sensitive = true
}

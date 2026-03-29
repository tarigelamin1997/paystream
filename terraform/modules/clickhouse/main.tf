data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "clickhouse" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name

  root_block_device {
    volume_type = "gp3"
    volume_size = var.ebs_size
    iops        = 3000
    throughput   = 125
    encrypted   = true
  }

  user_data = file("${path.module}/userdata.sh")

  tags = {
    Name = "${var.project_name}-clickhouse"
  }
}

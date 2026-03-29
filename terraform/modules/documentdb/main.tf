resource "random_password" "docdb_master" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "docdb_master" {
  name                    = "${var.project_name}-docdb-master-${var.environment}"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-docdb-master"
  }
}

resource "aws_secretsmanager_secret_version" "docdb_master" {
  secret_id = aws_secretsmanager_secret.docdb_master.id
  secret_string = jsonencode({
    username = "paystream_admin"
    password = random_password.docdb_master.result
    engine   = "docdb"
    host     = aws_docdb_cluster.main.endpoint
    port     = 27017
  })
}

resource "aws_docdb_subnet_group" "main" {
  name       = "${var.project_name}-docdb-subnet"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.project_name}-docdb-subnet"
  }
}

resource "aws_docdb_cluster_parameter_group" "main" {
  name   = "${var.project_name}-docdb-params"
  family = "docdb5.0"

  parameter {
    name  = "change_stream_log_retention_duration"
    value = "86400"
  }

  tags = {
    Name = "${var.project_name}-docdb-params"
  }
}

resource "aws_docdb_cluster" "main" {
  cluster_identifier              = "${var.project_name}-docdb"
  engine                          = "docdb"
  engine_version                  = "5.0.0"
  master_username                 = "paystream_admin"
  master_password                 = random_password.docdb_master.result
  db_subnet_group_name            = aws_docdb_subnet_group.main.name
  vpc_security_group_ids          = var.security_group_ids
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name
  storage_encrypted               = true
  skip_final_snapshot             = true
  deletion_protection             = false

  tags = {
    Name = "${var.project_name}-docdb"
  }
}

resource "aws_docdb_cluster_instance" "main" {
  identifier         = "${var.project_name}-docdb-instance-1"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.instance_class

  tags = {
    Name = "${var.project_name}-docdb-instance-1"
  }
}

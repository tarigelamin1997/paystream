resource "random_password" "rds_master" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "rds_master" {
  name                    = "${var.project_name}-rds-master-${var.environment}"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-rds-master"
  }
}

resource "aws_secretsmanager_secret_version" "rds_master" {
  secret_id = aws_secretsmanager_secret.rds_master.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.rds_master.result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = "${var.project_name}"
  })
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-rds-subnet"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.project_name}-rds-subnet"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-rds"
  engine         = "postgres"
  engine_version = "15"

  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  storage_type          = "gp3"
  db_name               = var.project_name
  username              = var.master_username
  password              = random_password.rds_master.result
  parameter_group_name  = aws_db_parameter_group.main.name
  db_subnet_group_name  = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids

  multi_az              = false
  publicly_accessible   = false
  skip_final_snapshot   = true
  deletion_protection   = false
  backup_retention_period = 1
  storage_encrypted     = true

  tags = {
    Name = "${var.project_name}-rds"
  }
}

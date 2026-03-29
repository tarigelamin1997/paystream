resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-pg15-params"
  family = "postgres15"

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "${var.project_name}-pg15-params"
  }
}

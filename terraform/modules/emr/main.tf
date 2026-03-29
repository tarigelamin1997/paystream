resource "aws_emrserverless_application" "main" {
  name          = "${var.project_name}-spark"
  release_label = "emr-7.0.0"
  type          = "SPARK"

  initial_capacity {
    initial_capacity_type = "Driver"

    initial_capacity_config {
      worker_count = 1
      worker_configuration {
        cpu    = "2 vCPU"
        memory = "4 GB"
      }
    }
  }

  maximum_capacity {
    cpu    = "8 vCPU"
    memory = "32 GB"
    disk   = "100 GB"
  }

  auto_stop_configuration {
    enabled              = true
    idle_timeout_minutes = 5
  }

  network_configuration {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  tags = {
    Name = "${var.project_name}-spark"
  }
}

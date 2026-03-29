resource "aws_mwaa_environment" "main" {
  name               = "${var.project_name}-mwaa"
  airflow_version    = "2.10.1"
  environment_class  = var.environment_class
  execution_role_arn = var.mwaa_execution_role_arn

  source_bucket_arn    = var.dags_bucket_arn
  dag_s3_path          = "dags/"
  requirements_s3_path = "requirements.txt"

  network_configuration {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = "INFO"
    }

    scheduler_logs {
      enabled   = true
      log_level = "INFO"
    }

    task_logs {
      enabled   = true
      log_level = "INFO"
    }

    webserver_logs {
      enabled   = true
      log_level = "INFO"
    }

    worker_logs {
      enabled   = true
      log_level = "INFO"
    }
  }

  webserver_access_mode = "PRIVATE_ONLY"
  max_workers           = 2
  min_workers           = 1

  tags = {
    Name = "${var.project_name}-mwaa"
  }
}

# MSK Provisioned — kafka.t3.small × 2 brokers
# Supports both IAM (Debezium, Schema Registry) and SCRAM-SHA-512 (ClickHouse)

resource "aws_kms_key" "msk_scram" {
  description = "KMS key for MSK SCRAM secret"

  tags = {
    Name = "${var.project_name}-msk-scram-kms"
  }
}

resource "random_password" "msk_scram" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "msk_scram" {
  name                    = "AmazonMSK_paystream_clickhouse"
  recovery_window_in_days = 0
  kms_key_id              = aws_kms_key.msk_scram.arn

  tags = {
    Name = "AmazonMSK_paystream_clickhouse"
  }
}

resource "aws_secretsmanager_secret_version" "msk_scram" {
  secret_id = aws_secretsmanager_secret.msk_scram.id
  secret_string = jsonencode({
    username = "clickhouse"
    password = random_password.msk_scram.result
  })
}

resource "aws_msk_configuration" "main" {
  name              = "${var.project_name}-msk-config"
  kafka_versions    = ["3.6.0"]

  server_properties = <<-EOT
    auto.create.topics.enable=true
    allow.everyone.if.no.acl.found=true
    default.replication.factor=2
    min.insync.replicas=1
    num.io.threads=8
    num.network.threads=5
    num.partitions=1
    num.replica.fetchers=2
    socket.request.max.bytes=104857600
    unclean.leader.election.enable=true
    log.retention.hours=168
  EOT
}

resource "aws_msk_cluster" "main" {
  cluster_name           = "${var.project_name}-msk"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type   = "kafka.t3.small"
    client_subnets  = var.subnet_ids
    security_groups = var.security_group_ids

    storage_info {
      ebs_storage_info {
        volume_size = 20
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.main.arn
    revision = aws_msk_configuration.main.latest_revision
  }

  client_authentication {
    sasl {
      iam   = true
      scram = true
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  tags = {
    Name = "${var.project_name}-msk"
  }
}

# Associate SCRAM secret with MSK cluster
resource "aws_msk_scram_secret_association" "main" {
  cluster_arn     = aws_msk_cluster.main.arn
  secret_arn_list = [aws_secretsmanager_secret.msk_scram.arn]

  depends_on = [aws_secretsmanager_secret_version.msk_scram]
}

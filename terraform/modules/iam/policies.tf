# MSK IAM auth policy — used by Debezium PG, Debezium Mongo, Schema Registry
resource "aws_iam_policy" "msk_iam_auth" {
  name = "${var.project_name}-msk-iam-auth"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:CreateTopic",
          "kafka-cluster:AlterTopic",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData",
          "kafka-cluster:DescribeGroup",
          "kafka-cluster:AlterGroup"
        ]
        Resource = [
          var.msk_cluster_arn,
          replace(var.msk_cluster_arn, ":cluster/", ":topic/"),
          "${replace(var.msk_cluster_arn, ":cluster/", ":topic/")}/*",
          replace(var.msk_cluster_arn, ":cluster/", ":group/"),
          "${replace(var.msk_cluster_arn, ":cluster/", ":group/")}/*",
          replace(var.msk_cluster_arn, ":cluster/", ":transactional-id/"),
          "${replace(var.msk_cluster_arn, ":cluster/", ":transactional-id/")}/*"
        ]
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-msk-iam-auth"
  }
}

# Attach MSK IAM policy to Debezium PG, Debezium Mongo, Schema Registry roles
resource "aws_iam_role_policy_attachment" "debezium_pg_msk" {
  role       = aws_iam_role.ecs_debezium_pg.name
  policy_arn = aws_iam_policy.msk_iam_auth.arn
}

resource "aws_iam_role_policy_attachment" "debezium_mongo_msk" {
  role       = aws_iam_role.ecs_debezium_mongo.name
  policy_arn = aws_iam_policy.msk_iam_auth.arn
}

resource "aws_iam_role_policy_attachment" "schema_registry_msk" {
  role       = aws_iam_role.ecs_schema_registry.name
  policy_arn = aws_iam_policy.msk_iam_auth.arn
}

# S3 access policy for EMR
resource "aws_iam_policy" "emr_s3_access" {
  name = "${var.project_name}-emr-s3-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = flatten([
          for arn in var.s3_bucket_arns : [arn, "${arn}/*"]
        ])
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-emr-s3-access"
  }
}

resource "aws_iam_role_policy_attachment" "emr_s3" {
  role       = aws_iam_role.emr_execution.name
  policy_arn = aws_iam_policy.emr_s3_access.arn
}

# MWAA S3 access (DAGs bucket)
resource "aws_iam_policy" "mwaa_s3_access" {
  name = "${var.project_name}-mwaa-s3-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration"
        ]
        Resource = flatten([
          for arn in var.s3_bucket_arns : [arn, "${arn}/*"]
        ])
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetAccountPublicAccessBlock"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-mwaa-s3-access"
  }
}

resource "aws_iam_role_policy_attachment" "mwaa_s3" {
  role       = aws_iam_role.mwaa_execution.name
  policy_arn = aws_iam_policy.mwaa_s3_access.arn
}

# MWAA base policy (CloudWatch Logs, SQS, etc.)
resource "aws_iam_policy" "mwaa_base" {
  name = "${var.project_name}-mwaa-base"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:GetLogRecord",
          "logs:GetLogGroupFields",
          "logs:GetQueryResults"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:airflow-*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
          "sqs:SendMessage"
        ]
        Resource = "arn:aws:sqs:${var.aws_region}:*:airflow-celery-*"
      },
      {
        Effect   = "Allow"
        Action   = "airflow:PublishMetrics"
        Resource = "arn:aws:airflow:${var.aws_region}:*:environment/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*",
          "kms:Encrypt"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:ViaService" = "sqs.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-mwaa-base"
  }
}

resource "aws_iam_role_policy_attachment" "mwaa_base" {
  role       = aws_iam_role.mwaa_execution.name
  policy_arn = aws_iam_policy.mwaa_base.arn
}

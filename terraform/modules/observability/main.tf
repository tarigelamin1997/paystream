# Amazon Managed Prometheus — available in eu-north-1
resource "aws_prometheus_workspace" "main" {
  alias = "${var.project_name}-prometheus"

  tags = {
    Name = "${var.project_name}-prometheus"
  }
}

# Amazon Managed Grafana — NOT available in eu-north-1
# AMG will need to be provisioned in a supported region (e.g., eu-west-1)
# or accessed via self-hosted Grafana on ECS. Deferred to Phase 6.
# resource "aws_grafana_workspace" "main" { ... }

resource "aws_iam_role" "grafana" {
  name = "${var.project_name}-grafana-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "grafana.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-grafana-role"
  }
}

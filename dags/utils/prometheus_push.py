"""Push metrics to Amazon Managed Prometheus.
Logs metrics to Airflow task log. AMP remote-write requires protobuf+snappy
which are not available in MWAA. For production, use a Lambda or sidecar."""
import os

AMP_ENDPOINT = os.environ.get("AMP_REMOTE_WRITE_URL", "")
REGION = os.environ.get("AWS_REGION", "eu-north-1")


def push_to_amp(metrics_dict):
    """Log metrics. Push to AMP if endpoint configured and protobuf available."""
    if not AMP_ENDPOINT:
        print("AMP_REMOTE_WRITE_URL not set — logging metrics locally")

    for name, (value, labels) in metrics_dict.items():
        label_str = ",".join(f'{k}="{v}"' for k, v in labels.items())
        print(f"  METRIC: {name}{{{label_str}}} = {value}")

    print(f"Logged {len(metrics_dict)} drift metrics")

    # AMP remote-write requires protobuf + snappy compression.
    # These are C-extension packages not available in MWAA.
    # For production: use a Lambda function or ECS sidecar to push.
    # For portfolio: metrics are logged in Airflow task logs, queryable
    # via CloudWatch Logs Insights.

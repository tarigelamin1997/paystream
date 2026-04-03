import json
import os
import boto3

sns = boto3.client("sns")
TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]


def handler(event, context):
    """Receive Grafana webhook POST, publish to SNS."""
    try:
        body = json.loads(event.get("body", "{}"))
        title = body.get("title", "Grafana Alert")[:100]
        state = body.get("state", "unknown")
        parts = [f"Alert: {title}", f"State: {state}"]

        for alert in body.get("alerts", [])[:5]:
            labels = alert.get("labels", {})
            annotations = alert.get("annotations", {})
            parts.append(f"\nRule: {labels.get('alertname', '?')}")
            parts.append(f"Status: {alert.get('status', '?')}")
            parts.append(f"Severity: {labels.get('severity', '?')}")
            summary = annotations.get("summary")
            if summary:
                parts.append(f"Summary: {summary}")

        sns.publish(
            TopicArn=TOPIC_ARN,
            Subject=f"[PayStream] {title}"[:100],
            Message="\n".join(parts)[:1000],
        )
        return {"statusCode": 200, "body": json.dumps({"status": "ok"})}
    except Exception as e:
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}

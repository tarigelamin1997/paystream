#!/usr/bin/env python3
"""Lightweight HTTP server that receives Grafana webhook POSTs and publishes to SNS."""
import json
import http.server
import boto3

SNS_TOPIC_ARN = "arn:aws:sns:eu-north-1:061664787519:paystream-alerts"
PORT = 9095

sns = boto3.client("sns", region_name="eu-north-1")


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode() if length else ""
        try:
            data = json.loads(body) if body else {}
            title = data.get("title", "Grafana Alert")[:100]
            msg = data.get("message", body)[:2000]
            alerts = data.get("alerts", [])
            if alerts:
                lines = []
                for a in alerts[:5]:
                    status = a.get("status", "?").upper()
                    name = a.get("labels", {}).get("alertname", "?")
                    lines.append(f"{status}: {name}")
                msg = "\n".join(lines)
                title = f"PayStream: {len(alerts)} alert(s)"
            sns.publish(TopicArn=SNS_TOPIC_ARN, Subject=title, Message=msg)
        except Exception as e:
            print(f"SNS publish error: {e}")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"status":"ok"}')

    def log_message(self, format, *args):
        pass


if __name__ == "__main__":
    print(f"Grafana SNS bridge listening on :{PORT}")
    http.server.HTTPServer(("", PORT), Handler).serve_forever()

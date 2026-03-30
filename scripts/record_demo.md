# PayStream Demo Recording Script

## Prerequisites
- SSH tunnel active: `ssh -L 3000:10.0.10.70:3000 -L 9000:10.0.10.70:9000 -i paystream-bastion.pem ec2-user@<bastion-eip>`
- Grafana accessible at http://localhost:3000 (admin/paystream)
- Screen recording software ready (OBS, Loom, or similar)

## Demo Flow (Target: 8-10 minutes)

### 1. Architecture Overview (1 min)
- Show the repo structure in terminal: `tree -L 2`
- Briefly mention: RDS -> Debezium -> MSK -> ClickHouse -> dbt -> Feature Store -> API

### 2. Data Pipeline (2 min)
- Open Grafana -> Pipeline SLOs dashboard
- Show Bronze ingestion is live (freshness < 30s)
- Show Gold layer freshness
- Show SLO summary table — all green

### 3. Merchant Operations (2 min)
- Open Grafana -> Merchant Operations dashboard
- Show GMV by merchant bar chart
- Show approval rate time series
- Show BNPL penetration gauge
- Show top 10 merchants table

### 4. Feature Store (2 min)
- Open Grafana -> Feature Store Health dashboard
- Show feature freshness stat
- Show row count
- Show version distribution
- Switch to Feature Drift Monitor
- Show drift scores over time
- Show baseline vs current comparison

### 5. Feature API (1 min)
- Terminal: `curl http://localhost:8000/features/42`
- Show JSON response with credit features
- Terminal: `curl http://localhost:8000/health`
- Show health check response

### 6. FinOps (1 min)
- Open Grafana -> FinOps dashboard
- Show storage by layer
- Show table engine distribution
- Show query cost top 10

### 7. Stress Test Results (1 min)
- Terminal: `cat stress_test/results/slo_results.json | python3 -m json.tool`
- Highlight all 6 SLOs met
- Show wave results if available

## Key Talking Points
- End-to-end CDC pipeline: PostgreSQL + DocumentDB -> MSK -> ClickHouse
- Four-layer warehouse: Bronze -> Silver -> Gold -> Feature Store
- Sub-50ms feature serving via FastAPI
- Drift detection with IQR-based scoring
- Full observability via Grafana dashboards and alerts
- Infrastructure as Code: single `terraform apply` deploys everything
- Cost control: `terraform destroy` tears down all resources

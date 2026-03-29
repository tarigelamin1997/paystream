#!/bin/bash
set -euo pipefail
# PayStream Phase 1 — Full deployment script
# Usage: ./scripts/deploy.sh

echo "=== PayStream Phase 1 Deploy ==="

echo "[1/7] Terraform Init..."
cd terraform && terraform init

echo "[2/7] Terraform Plan..."
terraform plan -var-file=environments/dev.tfvars

echo "[3/7] Terraform Apply..."
terraform apply -var-file=environments/dev.tfvars -auto-approve

echo "[4/7] Build and Push Debezium Images..."
cd ../
bash scripts/push_images.sh

echo "[5/7] Seed Data..."
bash scripts/seed_data.sh

echo "[6/7] Apply ClickHouse Bronze DDL..."
bash scripts/apply_clickhouse_ddl.sh

echo "[7/7] Register Debezium Connectors..."
bash scripts/register_connectors.sh

echo "=== Deploy Complete ==="
echo "Run 'make verify-phase1' to validate."

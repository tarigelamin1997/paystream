#!/bin/bash
set -euo pipefail
# PayStream Phase 1 — Teardown
echo "=== PayStream Phase 1 Teardown ==="
cd terraform && terraform destroy -var-file=environments/dev.tfvars -auto-approve
echo "=== Teardown Complete ==="

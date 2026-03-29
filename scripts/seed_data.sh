#!/bin/bash
set -euo pipefail
# Wrapper to run seed_data.py
# Run from bastion host with Python 3.12 + dependencies installed

echo "=== Seeding PayStream Data ==="
python3 scripts/seed_data.py
echo "=== Seeding Complete ==="

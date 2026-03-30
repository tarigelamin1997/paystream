#!/usr/bin/env bash
set -euo pipefail

# PayStream Preflight Check
# Verifies all required CLI tools are installed.

PASS=0
FAIL=0

check_cmd() {
  local name="$1"
  if command -v "$name" > /dev/null 2>&1; then
    local ver
    ver=$("$name" --version 2>&1 | head -1) || ver="installed"
    echo "  [OK] ${name}: ${ver}"
    PASS=$((PASS + 1))
  else
    echo "  [MISSING] ${name}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== PayStream Preflight Check ==="
echo ""

check_cmd "aws"
check_cmd "terraform"
check_cmd "docker"
check_cmd "python3"
check_cmd "dbt"
check_cmd "git"
check_cmd "curl"
check_cmd "jq"

echo ""
echo "Passed: ${PASS}, Missing: ${FAIL}"

if [[ ${FAIL} -eq 0 ]]; then
  echo "STATUS: All tools available"
  exit 0
else
  echo "STATUS: ${FAIL} tool(s) missing"
  exit 1
fi

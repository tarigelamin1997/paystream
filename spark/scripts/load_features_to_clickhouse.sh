#!/bin/bash
set -euo pipefail
# Alternative: load features from S3 Delta to ClickHouse if JDBC write failed
# Not needed if Spark dual-write succeeds
echo "Features are dual-written by Spark. This script is for manual recovery only."
echo "Use: spark-submit with --delta-path to re-read and write to ClickHouse."

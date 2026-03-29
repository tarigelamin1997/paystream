"""Configuration loaded exclusively from environment variables."""

import os

CLICKHOUSE_HOST = os.environ.get("CLICKHOUSE_HOST", "localhost")
CLICKHOUSE_PORT = int(os.environ.get("CLICKHOUSE_PORT", "9000"))
FEATURE_VERSION = os.environ.get("FEATURE_VERSION", "v2.1.0")
POOL_SIZE = 3

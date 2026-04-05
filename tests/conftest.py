"""Shared pytest fixtures for PayStream tests."""

import sys
from pathlib import Path
from unittest.mock import MagicMock

import pytest
from fastapi.testclient import TestClient

# Ensure api/ is importable
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "api"))

from feature_store.main import app  # noqa: E402


class MockClickHousePool:
    """Mock ClickHouse pool — no real database needed."""

    def __init__(self):
        self._mock_rows = []
        self._mock_columns = []

    def set_response(self, rows, columns):
        self._mock_rows = rows
        self._mock_columns = columns

    def get(self):
        conn = MagicMock()
        conn.execute.return_value = (self._mock_rows, self._mock_columns)
        return conn

    def put(self, conn):
        pass

    def ping(self):
        return True

    def close(self):
        pass


# Realistic columns matching the actual ClickHouse feature_store schema
FEATURE_COLUMNS = [
    ("user_id", "Int64"),
    ("snapshot_ts", "DateTime64(3)"),
    ("valid_from", "DateTime64(3)"),
    ("valid_to", "DateTime64(3)"),
    ("feature_version", "LowCardinality(String)"),
    ("tx_velocity_7d", "UInt16"),
    ("tx_velocity_30d", "UInt16"),
    ("avg_tx_amount_30d", "Decimal(10, 2)"),
    ("repayment_rate_90d", "Float32"),
    ("merchant_diversity_30d", "UInt8"),
    ("declined_rate_7d", "Float32"),
    ("active_installments", "UInt8"),
    ("days_since_first_tx", "UInt16"),
    ("_ingested_at", "DateTime"),
]


def make_feature_row(
    user_id=12345,
    snapshot_ts="2024-12-31 23:59:59.000",
    valid_from="2024-12-31 23:59:59.000",
    valid_to="2025-01-01 03:59:59.000",
    feature_version="v2.1.0",
    tx_velocity_7d=3,
    tx_velocity_30d=10,
    avg_tx_amount_30d=1500.50,
    repayment_rate_90d=0.85,
    merchant_diversity_30d=5,
    declined_rate_7d=0.1,
    active_installments=2,
    days_since_first_tx=287,
    ingested_at="2026-04-04 15:25:19",
):
    return (
        user_id, snapshot_ts, valid_from, valid_to, feature_version,
        tx_velocity_7d, tx_velocity_30d, avg_tx_amount_30d,
        repayment_rate_90d, merchant_diversity_30d, declined_rate_7d,
        active_installments, days_since_first_tx, ingested_at,
    )


@pytest.fixture()
def mock_pool():
    return MockClickHousePool()


@pytest.fixture()
def client(mock_pool):
    app.state.ch_pool = mock_pool
    return TestClient(app)

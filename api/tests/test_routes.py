"""Basic endpoint tests for the Feature Store API."""

from tests.conftest import MockClickHousePool


SAMPLE_COLUMNS = [
    ("user_id", "Int64"),
    ("feature_version", "String"),
    ("valid_from", "DateTime"),
    ("valid_to", "DateTime"),
    ("total_transactions", "Int64"),
    ("avg_transaction_amount", "Float64"),
    ("credit_utilization", "Float64"),
]

SAMPLE_ROW = (
    42,
    "v2.1.0",
    "2025-01-01 00:00:00",
    "2299-12-31 00:00:00",
    150,
    245.50,
    0.72,
)


def test_health_ok(client, mock_pool: MockClickHousePool):
    """Health endpoint returns healthy when ClickHouse is reachable."""
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "healthy"
    assert data["clickhouse"] == "ok"


def test_features_not_found(client, mock_pool: MockClickHousePool):
    """Returns 404 when no features exist for a user."""
    mock_pool.set_response(rows=[], columns=[])
    resp = client.get("/features/user/99999")
    assert resp.status_code == 404


def test_features_ok(client, mock_pool: MockClickHousePool):
    """Returns features for a valid user."""
    mock_pool.set_response(rows=[SAMPLE_ROW], columns=SAMPLE_COLUMNS)
    resp = client.get("/features/user/42")
    assert resp.status_code == 200
    data = resp.json()
    assert data["user_id"] == 42
    assert "features" in data
    assert data["features"]["total_transactions"] == 150
    assert data["features"]["credit_utilization"] == 0.72
    assert data["latency_ms"] >= 0


def test_metrics_endpoint(client):
    """Metrics endpoint returns Prometheus text format."""
    resp = client.get("/metrics")
    assert resp.status_code == 200
    assert "feature_latency_seconds" in resp.text

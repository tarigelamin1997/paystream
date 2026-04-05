"""Feature Store API endpoint tests with realistic mock data."""

from tests.conftest import FEATURE_COLUMNS, MockClickHousePool, make_feature_row


def test_health_ok(client, mock_pool: MockClickHousePool):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "healthy"
    assert resp.json()["clickhouse"] == "ok"


def test_features_valid_user(client, mock_pool: MockClickHousePool):
    mock_pool.set_response(rows=[make_feature_row()], columns=FEATURE_COLUMNS)
    resp = client.get("/features/user/12345")
    assert resp.status_code == 200
    data = resp.json()
    assert data["user_id"] == 12345
    assert data["feature_version"] == "v2.1.0"
    f = data["features"]
    assert f["tx_velocity_7d"] == 3
    assert f["repayment_rate_90d"] == pytest.approx(0.85, abs=0.01)
    assert f["days_since_first_tx"] == 287
    assert data["latency_ms"] >= 0


def test_features_missing_user(client, mock_pool: MockClickHousePool):
    mock_pool.set_response(rows=[], columns=[])
    resp = client.get("/features/user/99999")
    assert resp.status_code == 404


def test_temporal_query_returns_as_of(client, mock_pool: MockClickHousePool):
    mock_pool.set_response(rows=[make_feature_row()], columns=FEATURE_COLUMNS)
    resp = client.get("/features/user/12345?as_of=2024-09-15T00:00:00")
    assert resp.status_code == 200
    assert resp.json()["as_of"] == "2024-09-15T00:00:00"


def test_invalid_data_returns_503(client, mock_pool: MockClickHousePool):
    """ClickHouse returns a row with repayment_rate > 1.0 — Pydantic rejects it."""
    bad_row = make_feature_row(repayment_rate_90d=1.5)
    mock_pool.set_response(rows=[bad_row], columns=FEATURE_COLUMNS)
    resp = client.get("/features/user/12345")
    assert resp.status_code == 503
    assert "validation" in resp.json()["detail"]["reason"].lower()


# Need pytest import for approx
import pytest  # noqa: E402

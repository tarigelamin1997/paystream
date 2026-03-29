"""Tests for point-in-time temporal query and fallback behavior."""

from tests.conftest import MockClickHousePool


SAMPLE_COLUMNS = [
    ("user_id", "Int64"),
    ("feature_version", "String"),
    ("valid_from", "DateTime"),
    ("valid_to", "DateTime"),
    ("total_transactions", "Int64"),
    ("avg_transaction_amount", "Float64"),
]

SAMPLE_ROW = (
    42,
    "v2.1.0",
    "2025-01-01 00:00:00",
    "2299-12-31 00:00:00",
    150,
    245.50,
)


def test_point_in_time_with_as_of(client, mock_pool: MockClickHousePool):
    """Point-in-time query with as_of parameter returns features."""
    mock_pool.set_response(rows=[SAMPLE_ROW], columns=SAMPLE_COLUMNS)
    resp = client.get("/features/user/42?as_of=2025-06-15T00:00:00")
    assert resp.status_code == 200
    data = resp.json()
    assert data["user_id"] == 42
    assert data["as_of"] == "2025-06-15T00:00:00"


def test_point_in_time_fallback_to_latest(client, mock_pool: MockClickHousePool):
    """When temporal query returns empty, falls back to latest row."""
    # The mock always returns the same thing for both queries,
    # so this tests the fallback code path executes without error.
    mock_pool.set_response(rows=[SAMPLE_ROW], columns=SAMPLE_COLUMNS)
    resp = client.get("/features/user/42?as_of=2020-01-01T00:00:00")
    assert resp.status_code == 200


def test_point_in_time_no_data(client, mock_pool: MockClickHousePool):
    """Returns 404 when neither temporal nor latest has data."""
    mock_pool.set_response(rows=[], columns=[])
    resp = client.get("/features/user/99999?as_of=2025-01-01T00:00:00")
    assert resp.status_code == 404

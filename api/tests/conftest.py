"""Pytest fixtures with mock ClickHouse client."""

from unittest.mock import MagicMock

import pytest
from fastapi.testclient import TestClient

from feature_store.main import app


class MockClickHousePool:
    """Mock ClickHouse pool for testing without a real database."""

    def __init__(self) -> None:
        self._mock_rows: list = []
        self._mock_columns: list[tuple] = []

    def set_response(self, rows: list, columns: list[tuple]) -> None:
        """Configure the mock response for the next execute call."""
        self._mock_rows = rows
        self._mock_columns = columns

    def execute(self, query: str, params: dict | None = None) -> list:
        return self._mock_rows

    def get(self) -> MagicMock:
        conn = MagicMock()
        conn.execute.return_value = (self._mock_rows, self._mock_columns)
        return conn

    def put(self, conn: object) -> None:
        pass

    def ping(self) -> bool:
        return True

    def close(self) -> None:
        pass


@pytest.fixture()
def mock_pool() -> MockClickHousePool:
    return MockClickHousePool()


@pytest.fixture()
def client(mock_pool: MockClickHousePool) -> TestClient:
    """TestClient with mock ClickHouse pool injected."""
    app.state.ch_pool = mock_pool
    return TestClient(app)

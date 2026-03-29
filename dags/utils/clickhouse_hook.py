"""Custom ClickHouse hook for Airflow DAGs.
Uses HTTP interface (port 8123) via requests — no C-extension dependencies.
Compatible with MWAA without custom package installation."""
import os
import json
import requests

CLICKHOUSE_HOST = os.environ.get("CLICKHOUSE_HOST", "10.0.10.70")
CLICKHOUSE_PORT = os.environ.get("CLICKHOUSE_HTTP_PORT", "8123")
CLICKHOUSE_URL = f"http://{CLICKHOUSE_HOST}:{CLICKHOUSE_PORT}/"


def _auto_convert(v):
    """Convert string numbers to Python numeric types."""
    if not isinstance(v, str):
        return v
    try:
        if "." in v:
            return float(v)
        return int(v)
    except (ValueError, TypeError):
        return v


class Row(dict):
    """Dict that also supports positional indexing like a tuple.
    Auto-converts string values to numeric types."""
    def __init__(self, d):
        converted = {k: _auto_convert(v) for k, v in d.items()}
        super().__init__(converted)
        self._values = list(converted.values())

    def __getitem__(self, key):
        if isinstance(key, int):
            return self._values[key]
        return super().__getitem__(key)


def execute_clickhouse_query(sql, params=None):
    """Execute a ClickHouse query via HTTP. Returns list of Row objects.
    Each Row supports both dict access (row['col']) and tuple access (row[0])."""
    query = sql.strip()
    if params:
        for k, v in params.items():
            query = query.replace(f"%({k})s", str(v))

    is_select = query.upper().lstrip().startswith("SELECT")

    if is_select:
        resp = requests.post(
            CLICKHOUSE_URL,
            params={"default_format": "JSONEachRow"},
            data=query.encode("utf-8"),
            timeout=30,
        )
    else:
        resp = requests.post(
            CLICKHOUSE_URL,
            data=query.encode("utf-8"),
            timeout=30,
        )

    if resp.status_code != 200:
        raise Exception(f"ClickHouse HTTP {resp.status_code}: {resp.text[:500]}")

    if not is_select or not resp.text.strip():
        return []

    rows = []
    for line in resp.text.strip().split("\n"):
        if line.strip():
            rows.append(Row(json.loads(line)))
    return rows

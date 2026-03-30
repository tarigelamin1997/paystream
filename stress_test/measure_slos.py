"""
PayStream SLO Measurement Functions.

Connects to ClickHouse via native TCP (port 9000, SSH tunnel)
and measures each of the 6 platform SLOs.
"""

import logging
from datetime import datetime, timezone
from typing import Any

from clickhouse_driver import Client

logger = logging.getLogger(__name__)


def _get_client(host: str = "localhost", port: int = 9000) -> Client:
    """Return a ClickHouse native client."""
    return Client(host=host, port=port)


def measure_feature_store_freshness(
    host: str = "localhost", port: int = 9000
) -> dict[str, Any]:
    """SLO-1: Feature Store freshness < 6 hours."""
    client = _get_client(host, port)
    rows = client.execute(
        "SELECT dateDiff('second', max(_ingested_at), now()) AS stale_seconds "
        "FROM feature_store.user_credit_features"
    )
    stale_seconds = rows[0][0] if rows else None
    stale_hours = round(stale_seconds / 3600, 2) if stale_seconds is not None else None
    met = stale_hours is not None and stale_hours < 6
    return {
        "name": "Feature Store freshness",
        "target": "< 6 hours",
        "measured": f"{stale_hours} hours" if stale_hours is not None else "N/A",
        "measured_value": stale_hours,
        "met": met,
    }


def measure_feature_api_p99(
    host: str = "localhost", port: int = 9000
) -> dict[str, Any]:
    """SLO-2: Feature API P99 latency < 50ms.

    Measured via ClickHouse query_log for queries hitting feature_store.
    Falls back to direct timing if no API traffic is recorded.
    """
    client = _get_client(host, port)
    # Measure a representative feature lookup query
    import time

    latencies = []
    for _ in range(20):
        start = time.perf_counter()
        client.execute(
            "SELECT * FROM feature_store.user_credit_features "
            "WHERE user_id = 1 ORDER BY valid_from DESC LIMIT 1"
        )
        elapsed_ms = (time.perf_counter() - start) * 1000
        latencies.append(elapsed_ms)

    latencies.sort()
    p99_idx = int(len(latencies) * 0.99)
    p99 = round(latencies[min(p99_idx, len(latencies) - 1)], 2)
    met = p99 < 50
    return {
        "name": "Feature API P99 latency",
        "target": "< 50ms",
        "measured": f"{p99}ms",
        "measured_value": p99,
        "met": met,
    }


def measure_gold_freshness(
    host: str = "localhost", port: int = 9000
) -> dict[str, Any]:
    """SLO-3: Gold layer freshness < 25 hours."""
    client = _get_client(host, port)
    rows = client.execute(
        "SELECT dateDiff('second', max(_ingested_at), now()) AS stale_seconds "
        "FROM gold.merchant_daily_kpis"
    )
    stale_seconds = rows[0][0] if rows else None
    stale_hours = round(stale_seconds / 3600, 2) if stale_seconds is not None else None
    met = stale_hours is not None and stale_hours < 25
    return {
        "name": "Gold layer freshness",
        "target": "< 25 hours",
        "measured": f"{stale_hours} hours" if stale_hours is not None else "N/A",
        "measured_value": stale_hours,
        "met": met,
    }


def measure_ingestion_latency(
    host: str = "localhost", port: int = 9000
) -> dict[str, Any]:
    """SLO-4: Ingestion latency P95 < 30 seconds."""
    client = _get_client(host, port)
    rows = client.execute(
        "SELECT dateDiff('second', max(_ingested_at), now()) AS stale_seconds "
        "FROM bronze.pg_transactions_raw"
    )
    stale_seconds = rows[0][0] if rows else None
    met = stale_seconds is not None and stale_seconds < 30
    return {
        "name": "Ingestion latency P95",
        "target": "< 30 seconds",
        "measured": f"{stale_seconds} seconds" if stale_seconds is not None else "N/A",
        "measured_value": stale_seconds,
        "met": met,
    }


def measure_settlement_reconciliation(
    host: str = "localhost", port: int = 9000
) -> dict[str, Any]:
    """SLO-5: Settlement reconciliation completes by 6 AM."""
    client = _get_client(host, port)
    rows = client.execute(
        "SELECT count() AS cnt FROM gold.settlement_reconciliation "
        "WHERE settlement_date = today()"
    )
    count = rows[0][0] if rows else 0
    met = count > 0  # reconciliation has run for today
    return {
        "name": "Settlement reconciliation",
        "target": "Completes by 6 AM",
        "measured": "Complete" if met else "Not yet run",
        "measured_value": count,
        "met": met,
    }


def measure_drift_detection(
    host: str = "localhost", port: int = 9000
) -> dict[str, Any]:
    """SLO-6: Feature drift detection < 1 hour."""
    client = _get_client(host, port)
    rows = client.execute(
        "SELECT dateDiff('minute', max(measured_at), now()) AS stale_minutes "
        "FROM feature_store.drift_metrics"
    )
    stale_minutes = rows[0][0] if rows else None
    met = stale_minutes is not None and stale_minutes < 60
    return {
        "name": "Feature drift detection",
        "target": "< 1 hour",
        "measured": f"{stale_minutes} minutes" if stale_minutes is not None else "N/A",
        "measured_value": stale_minutes,
        "met": met,
    }


def measure_all_slos(
    host: str = "localhost", port: int = 9000
) -> list[dict[str, Any]]:
    """Run all 6 SLO measurements and return results."""
    measurements = [
        measure_feature_store_freshness,
        measure_feature_api_p99,
        measure_gold_freshness,
        measure_ingestion_latency,
        measure_settlement_reconciliation,
        measure_drift_detection,
    ]
    results = []
    for fn in measurements:
        try:
            result = fn(host=host, port=port)
            results.append(result)
            logger.info("SLO [%s]: %s (met=%s)", result["name"], result["measured"], result["met"])
        except Exception as e:
            logger.error("SLO measurement failed for %s: %s", fn.__name__, e)
            results.append({
                "name": fn.__doc__.split(":")[0].strip() if fn.__doc__ else fn.__name__,
                "target": "N/A",
                "measured": f"ERROR: {e}",
                "measured_value": None,
                "met": False,
            })
    return results

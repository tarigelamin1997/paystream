"""FastAPI routes for the Feature Store API."""

import logging
import time

from fastapi import APIRouter, HTTPException, Query, Request
from prometheus_client import generate_latest

from .config import FEATURE_VERSION
from .metrics import FEATURE_LATENCY, FEATURE_REQUESTS
from .models import FeatureResponse, HealthResponse

logger = logging.getLogger(__name__)
router = APIRouter()

# ---------------------------------------------------------------------------
# SQL templates — no JOINs, LIMIT 1, ORDER BY for P99 < 50ms
# ---------------------------------------------------------------------------

LATEST_QUERY = """
    SELECT *
    FROM feature_store.user_credit_features
    WHERE user_id = %(user_id)s
      AND feature_version = %(version)s
    ORDER BY valid_from DESC
    LIMIT 1
"""

POINT_IN_TIME_QUERY = """
    SELECT *
    FROM feature_store.user_credit_features
    WHERE user_id = %(user_id)s
      AND feature_version = %(version)s
      AND valid_from <= %(as_of)s
      AND valid_to > %(as_of)s
    ORDER BY valid_from DESC
    LIMIT 1
"""


def _row_to_features(row: tuple, columns: list[str]) -> dict:
    """Convert a ClickHouse row + column names into a features dict.

    Excludes the metadata columns (user_id, feature_version, valid_from,
    valid_to) so only actual feature values remain.
    """
    meta_keys = {"user_id", "feature_version", "valid_from", "valid_to"}
    return {
        col: val
        for col, val in zip(columns, row)
        if col not in meta_keys
    }


# ---------------------------------------------------------------------------
# Feature lookup
# ---------------------------------------------------------------------------


@router.get("/features/user/{user_id}", response_model=FeatureResponse)
async def get_features(
    request: Request,
    user_id: int,
    as_of: str | None = Query(default=None, description="ISO timestamp for point-in-time lookup"),
) -> FeatureResponse:
    """Retrieve credit features for a user.

    Real-time path (no as_of): returns the LATEST row.
    Point-in-time path (as_of provided): tries temporal range first,
    falls back to LATEST if no rows match (handles far-future valid_to).
    """
    pool = request.app.state.ch_pool
    params = {"user_id": user_id, "version": FEATURE_VERSION}

    start = time.perf_counter()
    try:
        # Single query with column types — no double-fetch
        conn = pool.get()
        try:
            if as_of is None:
                # Real-time: just get the latest row
                result = conn.execute(LATEST_QUERY, params, with_column_types=True)
            else:
                # Point-in-time: try temporal first
                params["as_of"] = as_of
                result = conn.execute(POINT_IN_TIME_QUERY, params, with_column_types=True)
                if not result[0]:
                    # Fallback to latest (far-future valid_to edge case)
                    result = conn.execute(LATEST_QUERY, params, with_column_types=True)
        finally:
            pool.put(conn)

        elapsed_ms = (time.perf_counter() - start) * 1000
        FEATURE_LATENCY.observe(elapsed_ms / 1000)

        data_rows, col_types = result
        if not data_rows:
            FEATURE_REQUESTS.labels(status="not_found").inc()
            raise HTTPException(status_code=404, detail=f"No features for user_id={user_id}")

        columns = [c[0] for c in col_types]
        features = _row_to_features(data_rows[0], columns)

        FEATURE_REQUESTS.labels(status="ok").inc()
        return FeatureResponse(
            user_id=user_id,
            as_of=as_of,
            feature_version=FEATURE_VERSION,
            latency_ms=round(elapsed_ms, 2),
            features=features,
        )

    except HTTPException:
        raise
    except Exception as exc:
        elapsed_ms = (time.perf_counter() - start) * 1000
        FEATURE_LATENCY.observe(elapsed_ms / 1000)
        FEATURE_REQUESTS.labels(status="error").inc()
        logger.exception("Feature lookup failed for user_id=%d", user_id)
        raise HTTPException(status_code=500, detail=str(exc))


# ---------------------------------------------------------------------------
# Health check (ALB target group)
# ---------------------------------------------------------------------------


@router.get("/health", response_model=HealthResponse)
async def health(request: Request) -> HealthResponse:
    """ALB health check — verifies ClickHouse connectivity."""
    pool = request.app.state.ch_pool
    ch_ok = pool.ping()
    return HealthResponse(
        status="healthy" if ch_ok else "degraded",
        clickhouse="ok" if ch_ok else "unreachable",
        version=FEATURE_VERSION,
    )


# ---------------------------------------------------------------------------
# Prometheus metrics
# ---------------------------------------------------------------------------


@router.get("/metrics")
async def metrics() -> bytes:
    """Expose Prometheus metrics in text format."""
    from starlette.responses import Response

    return Response(
        content=generate_latest(),
        media_type="text/plain; version=0.0.4; charset=utf-8",
    )

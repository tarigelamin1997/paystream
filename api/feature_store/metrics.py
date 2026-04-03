"""Prometheus metrics for the Feature Store API."""

from prometheus_client import Counter, Histogram

FEATURE_LATENCY = Histogram(
    "paystream_feature_request_latency_seconds",
    "Feature Store API latency",
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0],
)

FEATURE_REQUESTS = Counter(
    "paystream_feature_requests_total",
    "Total Feature Store API requests",
    ["status"],
)

FEATURE_VALIDATION_FAILURES = Counter(
    "paystream_feature_validation_failures_total",
    "Number of feature requests that failed Pydantic validation",
)

CIRCUIT_BREAKER_TRIPS = Counter(
    "paystream_circuit_breaker_trips_total",
    "Number of requests rejected by circuit breaker (ClickHouse unavailable)",
)

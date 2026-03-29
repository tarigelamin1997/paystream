"""Pydantic response models for the Feature Store API."""

from pydantic import BaseModel


class FeatureResponse(BaseModel):
    """Response model for feature lookup."""

    user_id: int
    as_of: str | None
    feature_version: str
    latency_ms: float
    features: dict


class HealthResponse(BaseModel):
    """Response model for health check."""

    status: str
    clickhouse: str
    version: str

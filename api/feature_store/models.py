"""Pydantic response models for the Feature Store API."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field, field_validator


class FeatureValues(BaseModel):
    """Validated feature values from the Feature Store.

    Enforces range constraints on all feature columns to prevent
    serving corrupt or invalid data to downstream consumers.
    """

    snapshot_ts: Any  # DateTime64 from ClickHouse, pass through
    tx_velocity_7d: int = Field(ge=0)
    tx_velocity_30d: int = Field(ge=0)
    avg_tx_amount_30d: float = Field(ge=0)
    repayment_rate_90d: float = Field(ge=0, le=1)
    merchant_diversity_30d: int = Field(ge=0)
    declined_rate_7d: float = Field(ge=0, le=1)
    active_installments: int = Field(ge=0)
    days_since_first_tx: int = Field(ge=0)

    model_config = {"extra": "allow"}

    @field_validator(
        "tx_velocity_7d", "tx_velocity_30d", "avg_tx_amount_30d",
        "repayment_rate_90d", "merchant_diversity_30d", "declined_rate_7d",
        "active_installments", "days_since_first_tx",
        mode="before",
    )
    @classmethod
    def coerce_numeric(cls, v):
        if v is None:
            raise ValueError("feature value cannot be NULL")
        return float(v) if isinstance(v, (str,)) else v


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

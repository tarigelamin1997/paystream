"""Pydantic FeatureValues model boundary tests."""

import pytest
from pydantic import ValidationError

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "api"))

from feature_store.models import FeatureValues  # noqa: E402


def _valid_features(**overrides):
    base = {
        "snapshot_ts": "2024-12-31T23:59:59",
        "tx_velocity_7d": 3,
        "tx_velocity_30d": 10,
        "avg_tx_amount_30d": 1500.50,
        "repayment_rate_90d": 0.85,
        "merchant_diversity_30d": 5,
        "declined_rate_7d": 0.1,
        "active_installments": 2,
        "days_since_first_tx": 287,
    }
    base.update(overrides)
    return base


def test_valid_data_passes():
    model = FeatureValues(**_valid_features())
    assert model.tx_velocity_7d == 3
    assert model.repayment_rate_90d == pytest.approx(0.85, abs=0.01)
    assert model.days_since_first_tx == 287


def test_negative_velocity_rejected():
    with pytest.raises(ValidationError) as exc_info:
        FeatureValues(**_valid_features(tx_velocity_7d=-1))
    assert "tx_velocity_7d" in str(exc_info.value)


def test_rate_above_one_rejected():
    with pytest.raises(ValidationError) as exc_info:
        FeatureValues(**_valid_features(repayment_rate_90d=1.5))
    assert "repayment_rate_90d" in str(exc_info.value)


def test_null_feature_rejected():
    with pytest.raises(ValidationError):
        FeatureValues(**_valid_features(avg_tx_amount_30d=None))


def test_string_decimal_coerced():
    """Decimal amounts come as strings from ClickHouse HTTP — must coerce."""
    model = FeatureValues(**_valid_features(avg_tx_amount_30d="2742.58"))
    assert model.avg_tx_amount_30d == pytest.approx(2742.58, abs=0.01)

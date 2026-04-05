"""Tests for compute_features.py validation logic.

The validate_features() function writes DQ results to ClickHouse,
which we mock out. We test the validation logic and row filtering only.
"""

from unittest.mock import patch

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "dags"))


def _feature_row(**overrides):
    base = {
        "tx_velocity_7d": 5,
        "tx_velocity_30d": 15,
        "avg_tx_amount_30d": 2500.0,
        "repayment_rate_90d": 0.75,
        "merchant_diversity_30d": 8,
        "declined_rate_7d": 0.1,
        "active_installments": 3,
        "days_since_first_tx": 200,
    }
    base.update(overrides)
    return base


@patch("utils.compute_features._write_dq_result")
def test_clean_data_passes(mock_dq):
    from utils.compute_features import validate_features
    rows = [_feature_row(), _feature_row(tx_velocity_7d=2, tx_velocity_30d=8)]
    result = validate_features(rows)
    assert len(result) == 2


@patch("utils.compute_features._write_dq_result")
def test_null_rejection(mock_dq):
    from utils.compute_features import validate_features
    rows = [_feature_row(), _feature_row(repayment_rate_90d=None)]
    result = validate_features(rows)
    assert len(result) == 1  # NULL row removed


@patch("utils.compute_features._write_dq_result")
def test_negative_amount_rejection(mock_dq):
    from utils.compute_features import validate_features
    rows = [_feature_row(avg_tx_amount_30d=-50.0)]
    result = validate_features(rows)
    assert len(result) == 0  # negative row removed


@patch("utils.compute_features._write_dq_result")
def test_rate_above_one_rejection(mock_dq):
    from utils.compute_features import validate_features
    rows = [_feature_row(repayment_rate_90d=1.5)]
    result = validate_features(rows)
    assert len(result) == 0  # out-of-range row removed


@patch("utils.compute_features._write_dq_result")
def test_velocity_ordering_warning(mock_dq):
    """tx_velocity_7d > tx_velocity_30d is a warning, not a rejection."""
    from utils.compute_features import validate_features
    rows = [_feature_row(tx_velocity_7d=20, tx_velocity_30d=5)]
    result = validate_features(rows)
    # Velocity ordering is a warning — row is NOT removed
    assert len(result) == 1
    # But the DQ result for velocity_ordering should have been called with "warn"
    calls = [c for c in mock_dq.call_args_list if c[0][0] == "velocity_ordering"]
    assert len(calls) == 1
    assert calls[0][0][2] == "warn"  # status argument

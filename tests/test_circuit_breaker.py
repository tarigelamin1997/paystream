"""Circuit breaker state machine tests."""

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "api"))

from feature_store.routes import CircuitBreaker  # noqa: E402


def test_starts_closed():
    cb = CircuitBreaker(failure_threshold=3, recovery_timeout=30)
    assert cb.state == CircuitBreaker.CLOSED
    assert cb.can_execute() is True


def test_opens_after_threshold_failures():
    cb = CircuitBreaker(failure_threshold=3, recovery_timeout=30)
    cb.record_failure()
    assert cb.state == CircuitBreaker.CLOSED
    cb.record_failure()
    assert cb.state == CircuitBreaker.CLOSED
    cb.record_failure()
    assert cb.state == CircuitBreaker.OPEN
    assert cb.can_execute() is False


def test_open_rejects_requests():
    cb = CircuitBreaker(failure_threshold=1, recovery_timeout=999)
    cb.record_failure()
    assert cb.state == CircuitBreaker.OPEN
    assert cb.can_execute() is False


def test_transitions_to_half_open_after_recovery_timeout():
    cb = CircuitBreaker(failure_threshold=1, recovery_timeout=0.1)
    cb.record_failure()
    assert cb.state == CircuitBreaker.OPEN
    time.sleep(0.15)
    assert cb.can_execute() is True
    assert cb.state == CircuitBreaker.HALF_OPEN


def test_resets_to_closed_on_success():
    cb = CircuitBreaker(failure_threshold=1, recovery_timeout=0.1)
    cb.record_failure()
    assert cb.state == CircuitBreaker.OPEN
    time.sleep(0.15)
    cb.can_execute()  # transitions to HALF_OPEN
    cb.record_success()
    assert cb.state == CircuitBreaker.CLOSED
    assert cb.failure_count == 0

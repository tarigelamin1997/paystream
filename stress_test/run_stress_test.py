#!/usr/bin/env python3
"""
PayStream Stress Test Runner.

Executes waves defined in stress_config.yaml, running concurrent ClickHouse
queries per wave and measuring SLOs after each wave. Results are written to
results/slo_results.json.

Usage:
    python3 run_stress_test.py [--host localhost] [--port 9000] [--config stress_config.yaml]
"""

import argparse
import concurrent.futures
import json
import logging
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import yaml
from clickhouse_driver import Client

# Add parent to path for measure_slos import
sys.path.insert(0, str(Path(__file__).parent))
from measure_slos import measure_all_slos

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

# Representative queries that stress different ClickHouse layers
STRESS_QUERIES = [
    "SELECT count() FROM bronze.pg_transactions_raw",
    "SELECT merchant_id, count() FROM silver.transactions_silver GROUP BY merchant_id",
    "SELECT * FROM feature_store.user_credit_features WHERE user_id = 42 LIMIT 1",
    "SELECT sum(total_amount) FROM silver.transactions_silver WHERE _ingested_at >= now() - INTERVAL 1 HOUR",
    "SELECT database, sum(rows) FROM system.parts WHERE active GROUP BY database",
    "SELECT count(), avg(total_amount) FROM gold.merchant_daily_kpis",
    "SELECT feature_name, avg(drift_score) FROM feature_store.drift_metrics GROUP BY feature_name",
]


def run_query(host: str, port: int, query: str) -> float:
    """Execute a single query and return elapsed milliseconds."""
    client = Client(host=host, port=port)
    start = time.perf_counter()
    client.execute(query)
    return (time.perf_counter() - start) * 1000


def run_wave(
    wave: dict, host: str, port: int
) -> dict:
    """Run a single stress wave and return timing stats."""
    name = wave["name"]
    concurrency = wave["concurrent_queries"]
    duration_s = wave["duration_seconds"]
    interval_ms = wave["query_interval_ms"]

    logger.info("=== Wave: %s (concurrency=%d, duration=%ds) ===", name, concurrency, duration_s)

    latencies = []
    errors = 0
    end_time = time.time() + duration_s

    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as pool:
        while time.time() < end_time:
            futures = []
            for i in range(concurrency):
                query = STRESS_QUERIES[i % len(STRESS_QUERIES)]
                futures.append(pool.submit(run_query, host, port, query))

            for f in concurrent.futures.as_completed(futures):
                try:
                    latencies.append(f.result())
                except Exception as e:
                    errors += 1
                    logger.warning("Query error in %s: %s", name, e)

            time.sleep(interval_ms / 1000.0)

    latencies.sort()
    total = len(latencies)
    stats = {
        "wave": name,
        "total_queries": total,
        "errors": errors,
        "p50_ms": round(latencies[int(total * 0.5)] if total else 0, 2),
        "p95_ms": round(latencies[int(total * 0.95)] if total else 0, 2),
        "p99_ms": round(latencies[int(total * 0.99)] if total else 0, 2),
        "max_ms": round(latencies[-1] if total else 0, 2),
    }
    logger.info("  Results: queries=%d errors=%d p95=%.1fms p99=%.1fms", total, errors, stats["p95_ms"], stats["p99_ms"])
    return stats


def main():
    parser = argparse.ArgumentParser(description="PayStream Stress Test")
    parser.add_argument("--host", default="localhost", help="ClickHouse host")
    parser.add_argument("--port", type=int, default=9000, help="ClickHouse native port")
    parser.add_argument("--config", default=str(Path(__file__).parent / "stress_config.yaml"))
    args = parser.parse_args()

    with open(args.config) as f:
        config = yaml.safe_load(f)

    logger.info("PayStream Stress Test — %s", config["test_name"])
    logger.info("Target: %s:%d", args.host, args.port)

    # Pre-flight: verify connectivity
    try:
        client = Client(host=args.host, port=args.port)
        client.execute("SELECT 1")
        logger.info("ClickHouse connection OK")
    except Exception as e:
        logger.error("Cannot connect to ClickHouse: %s", e)
        sys.exit(1)

    # Run waves
    wave_results = []
    for wave in config["waves"]:
        stats = run_wave(wave, args.host, args.port)
        wave_results.append(stats)

    # Measure SLOs after all waves
    logger.info("=== Measuring SLOs ===")
    slo_results = measure_all_slos(host=args.host, port=args.port)

    # Build output
    output = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "config": config["test_name"],
        "wave_results": wave_results,
        "slos": slo_results,
        "all_slos_met": all(s["met"] for s in slo_results),
    }

    # Write results
    results_dir = Path(__file__).parent / "results"
    results_dir.mkdir(exist_ok=True)
    results_file = results_dir / "slo_results.json"
    with open(results_file, "w") as f:
        json.dump(output, f, indent=2, default=str)

    logger.info("Results written to %s", results_file)
    logger.info("All SLOs met: %s", output["all_slos_met"])

    # Exit code reflects SLO compliance
    sys.exit(0 if output["all_slos_met"] else 1)


if __name__ == "__main__":
    main()

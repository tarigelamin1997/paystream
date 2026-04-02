import json, glob, os
DS_REF = {"type": "grafana-clickhouse-datasource", "uid": "PDEE91DDB90597936"}
PANEL_QUERIES = {
    "Drift Score": {"rawSql": "SELECT measured_at AS time, feature_name, drift_score FROM feature_store.drift_metrics ORDER BY measured_at", "format": 0},
    "Baseline vs Current": {"rawSql": "SELECT feature_name, baseline_median, current_median FROM feature_store.drift_metrics WHERE measured_at = (SELECT max(measured_at) FROM feature_store.drift_metrics)", "format": 1},
    "IQR Threshold": {"rawSql": "SELECT feature_name, drift_score, if(drift_score > 3.0, 'EXCEEDED', 'OK') AS status FROM feature_store.drift_metrics WHERE measured_at = (SELECT max(measured_at) FROM feature_store.drift_metrics) ORDER BY drift_score DESC", "format": 1},
    "Drift Detected": {"rawSql": "SELECT count() AS drifted_features FROM feature_store.drift_metrics WHERE is_drifted = 1 AND measured_at = (SELECT max(measured_at) FROM feature_store.drift_metrics)", "format": 1},
    "Last Drift": {"rawSql": "SELECT max(measured_at) AS last_drift FROM feature_store.drift_metrics WHERE is_drifted = 1", "format": 1},
    "Feature Freshness": {"rawSql": "SELECT max(_ingested_at) AS last_update FROM feature_store.user_credit_features", "format": 1},
    "P99 Latency": {"rawSql": "SELECT toStartOfMinute(event_time) AS time, quantile(0.99)(query_duration_ms) AS p99_ms FROM system.query_log WHERE query LIKE '%feature_store%' AND type = 'QueryFinish' AND event_time >= now() - INTERVAL 24 HOUR GROUP BY time ORDER BY time", "format": 0},
    "Request Rate": {"rawSql": "SELECT toStartOfMinute(event_time) AS time, count() AS requests FROM system.query_log WHERE query LIKE '%feature_store%' AND type = 'QueryFinish' AND event_time >= now() - INTERVAL 24 HOUR GROUP BY time ORDER BY time", "format": 0},
    "Row Count": {"rawSql": "SELECT count() AS total_rows FROM feature_store.user_credit_features", "format": 1},
    "Version Distribution": {"rawSql": "SELECT feature_version, count() AS cnt FROM feature_store.user_credit_features GROUP BY feature_version ORDER BY cnt DESC", "format": 1},
    "GMV": {"rawSql": "SELECT merchant_id, merchant_category, gmv, transaction_count, approval_rate FROM gold.merchant_daily_kpis ORDER BY gmv DESC", "format": 1},
    "Approval Rate": {"rawSql": "SELECT merchant_id, date, approval_rate FROM gold.merchant_daily_kpis ORDER BY merchant_id, date", "format": 1},
    "BNPL": {"rawSql": "SELECT avg(bnpl_penetration) AS avg_bnpl FROM gold.merchant_daily_kpis", "format": 1},
    "Decision Latency": {"rawSql": "SELECT quantile(0.50)(decision_latency_ms) AS p50, quantile(0.95)(decision_latency_ms) AS p95, quantile(0.99)(decision_latency_ms) AS p99 FROM silver.transactions_silver WHERE _ingested_at > now() - INTERVAL 24 HOUR", "format": 1},
    "Top 10": {"rawSql": "SELECT merchant_id, sum(gmv) AS total_gmv FROM gold.merchant_daily_kpis GROUP BY merchant_id ORDER BY total_gmv DESC LIMIT 10", "format": 1},
    "Ingestion": {"rawSql": "SELECT max(_ingested_at) AS last_ingested, dateDiff('minute', max(_ingested_at), now()) AS lag_minutes FROM bronze.pg_transactions_raw", "format": 1},
    "dbt": {"rawSql": "SELECT test_name, status, execution_time, tested_at FROM gold.dbt_test_results ORDER BY tested_at DESC LIMIT 10", "format": 1},
    "Gold Freshness": {"rawSql": "SELECT max(_ingested_at) AS last_update FROM gold.merchant_daily_kpis", "format": 1},
    "Feature Pipeline": {"rawSql": "SELECT max(_ingested_at) AS last_feature_update, dateDiff('hour', max(_ingested_at), now()) AS hours_since FROM feature_store.user_credit_features", "format": 1},
    "Settlement": {"rawSql": "SELECT settlement_date, count() AS merchants, countIf(status = 'matched') AS matched, countIf(status = 'mismatch') AS mismatches FROM gold.settlement_reconciliation GROUP BY settlement_date ORDER BY settlement_date DESC LIMIT 5", "format": 1},
    "SLO Summary": {"rawSql": "SELECT 'Feature Freshness' AS slo, '<6h' AS target, if(dateDiff('hour', max_ts, now()) < 6, 'PASS', 'FAIL') AS status FROM (SELECT max(_ingested_at) AS max_ts FROM feature_store.user_credit_features)", "format": 1},
    "Storage": {"rawSql": "SELECT database, formatReadableSize(sum(bytes_on_disk)) AS disk_usage, sum(rows) AS total_rows FROM system.parts WHERE active GROUP BY database ORDER BY sum(bytes_on_disk) DESC", "format": 1},
    "Query Cost": {"rawSql": "SELECT type, substring(query, 1, 80) AS query_short, read_rows, formatReadableSize(read_bytes) AS read_size, query_duration_ms FROM system.query_log WHERE type = 'QueryFinish' AND event_time >= now() - INTERVAL 1 HOUR ORDER BY read_bytes DESC LIMIT 10", "format": 1},
    "Spark": {"rawSql": "SELECT 0 AS executor_hours", "format": 1},
    "Invocations": {"rawSql": "SELECT toStartOfHour(event_time) AS time, count() AS queries FROM system.query_log WHERE query LIKE '%feature_store%' AND type = 'QueryFinish' AND event_time >= now() - INTERVAL 24 HOUR GROUP BY time ORDER BY time", "format": 0},
    "Engine Distribution": {"rawSql": "SELECT database, engine, count() AS table_count FROM system.tables WHERE database IN ('bronze','silver','gold','feature_store') GROUP BY database, engine ORDER BY database, engine", "format": 1},
}
fixed = 0
for f in sorted(glob.glob("/etc/grafana/paystream/dashboards/*.json")):
    with open(f) as fh:
        d = json.load(fh)
    fname = os.path.basename(f)
    changed = False
    for panel in d.get("panels", []):
        title = panel.get("title", "")
        panel["datasource"] = DS_REF
        for target in panel.get("targets", []):
            target["datasource"] = DS_REF
            target["editorType"] = "sql"
            target["queryType"] = "sql"
            current = target.get("rawSql", "").strip()
            for key, fix in PANEL_QUERIES.items():
                if key.lower() in title.lower():
                    target["rawSql"] = fix["rawSql"]
                    target["format"] = fix["format"]
                    if current != fix["rawSql"]:
                        changed = True
                        fixed += 1
                        print("FIXED: " + fname + " / " + title)
                    break
            else:
                if not current:
                    print("EMPTY: " + fname + " / " + title)
    if changed:
        with open(f, "w") as fh:
            json.dump(d, fh, indent=2)
print(str(fixed) + " panels fixed")

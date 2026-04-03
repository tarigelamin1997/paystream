import json

f = "/etc/grafana/paystream/dashboards/04_pipeline_slos.json"
with open(f) as fh:
    d = json.load(fh)

DS_REF = {"type": "grafana-clickhouse-datasource", "uid": "PDEE91DDB90597936"}

for panel in d.get("panels", []):
    title = panel.get("title", "")
    for target in panel.get("targets", []):
        target["datasource"] = DS_REF
        target["editorType"] = "sql"
        target["queryType"] = "sql"

        if "Gold Freshness" in title or "Gold Layer" in title:
            target["rawSql"] = "SELECT max(modification_time) AS last_gold_update FROM system.parts WHERE database = 'gold' AND active"
            target["format"] = 1
            print("Fixed: " + title)

        elif "Feature Pipeline" in title:
            target["rawSql"] = "SELECT max(_ingested_at) AS last_feature_update, dateDiff('hour', max(_ingested_at), now()) AS hours_since_update FROM feature_store.user_credit_features"
            target["format"] = 1
            print("Fixed: " + title)

        elif "Settlement" in title:
            target["rawSql"] = "SELECT settlement_date, count() AS merchants, countIf(status = 'matched') AS matched, countIf(status = 'mismatch') AS mismatches, avg(variance_pct) AS avg_variance_pct FROM gold.settlement_reconciliation GROUP BY settlement_date ORDER BY settlement_date DESC LIMIT 5"
            target["format"] = 1
            print("Fixed: " + title)

with open(f, "w") as fh:
    json.dump(d, fh, indent=2)
print("Saved")

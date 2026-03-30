# PayStream Stress Test Report

**Date:** {{timestamp}}
**Configuration:** {{config_name}}
**ClickHouse Host:** {{host}}:{{port}}

---

## Wave Results

| Wave | Queries | Errors | P50 (ms) | P95 (ms) | P99 (ms) | Max (ms) |
|------|---------|--------|----------|----------|----------|----------|
{{#waves}}
| {{wave}} | {{total_queries}} | {{errors}} | {{p50_ms}} | {{p95_ms}} | {{p99_ms}} | {{max_ms}} |
{{/waves}}

---

## SLO Results

| SLO | Target | Measured | Met? |
|-----|--------|----------|------|
{{#slos}}
| {{name}} | {{target}} | {{measured}} | {{#met}}YES{{/met}}{{^met}}**NO**{{/met}} |
{{/slos}}

---

## Summary

- **All SLOs Met:** {{all_slos_met}}
- **Total Waves:** {{total_waves}}
- **Total Queries Executed:** {{total_queries}}
- **Total Errors:** {{total_errors}}

## Notes

- Stress test measures SLOs against existing data (no new inserts during test).
- ClickHouse accessed via SSH tunnel to private subnet.
- Feature API P99 measured via direct ClickHouse query latency as proxy.

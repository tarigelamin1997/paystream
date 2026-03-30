# PayStream Demo Queries

SQL queries for demonstrating PayStream platform capabilities. Run these against the ClickHouse instance via SSH tunnel through the bastion host.

## Connection

```bash
# SSH tunnel to ClickHouse
ssh -i ~/.ssh/paystream-bastion.pem -L 8123:CLICKHOUSE_PRIVATE_IP:8123 ec2-user@BASTION_EIP

# Then query via HTTP
curl 'http://localhost:8123/?query=SELECT+1'

# Or use clickhouse-client
clickhouse-client --host localhost --port 9000
```

---

## 1. Bronze Layer -- CDC Row Counts

Verify that CDC is flowing from both PostgreSQL and DocumentDB into the Bronze layer.

```sql
SELECT 'transactions' AS table, count() AS rows FROM bronze.pg_transactions_raw
UNION ALL SELECT 'users', count() FROM bronze.pg_users_raw
UNION ALL SELECT 'merchants', count() FROM bronze.pg_merchants_raw
UNION ALL SELECT 'repayments', count() FROM bronze.pg_repayments_raw
UNION ALL SELECT 'installments', count() FROM bronze.pg_installments_raw
UNION ALL SELECT 'app_events', count() FROM bronze.mongo_app_events_raw;
```

**Expected:** ~50K users, ~200K transactions, ~150K repayments, ~100K installments, ~500K app events.

---

## 2. Silver Layer -- Deduplicated Counts

Confirm that ReplacingMergeTree deduplication is working in the Silver layer.

```sql
SELECT count() AS users FROM silver.users_silver FINAL;
```

**Expected:** Exactly 50,000 users (matching seed data). The `FINAL` modifier forces deduplication at query time.

---

## 3. Gold -- Merchant Daily KPIs (Top 10 by GMV)

Show the top merchants by gross merchandise volume from the Gold layer.

```sql
SELECT
    merchant_id,
    merchant_category,
    gmv,
    transaction_count,
    approval_rate
FROM gold.merchant_daily_kpis
ORDER BY gmv DESC
LIMIT 10;
```

**Expected:** Top merchants with GMV in descending order, approval rates between 0.70-0.95.

---

## 4. Feature Store -- Point-in-Time Query

Retrieve computed credit features for a specific user.

```sql
SELECT
    user_id,
    tx_velocity_7d,
    tx_velocity_30d,
    avg_tx_amount_30d,
    repayment_rate_90d,
    merchant_diversity_30d,
    feature_version
FROM feature_store.user_credit_features
WHERE user_id = 5002;
```

**Expected:** One or more rows showing feature values at different points in time, with `feature_version` indicating the computation batch.

---

## 5. Active Credit Exposure -- Top 10 Users

Query the AggregatingMergeTree table for running credit exposure sums.

```sql
SELECT
    user_id,
    sumMerge(active_exposure) AS exposure
FROM silver.user_active_credit
GROUP BY user_id
ORDER BY exposure DESC
LIMIT 10;
```

**Expected:** Users with highest outstanding credit exposure. Uses `sumMerge()` to finalize the AggregatingMergeTree partial aggregates.

---

## 6. Risk Dashboard -- Daily Metrics

Display platform-wide risk metrics used by the Grafana risk dashboard.

```sql
SELECT
    date,
    approval_rate,
    decline_rate,
    avg_decision_latency_ms,
    total_exposure
FROM gold.risk_dashboard;
```

**Expected:** One row per day with aggregate risk metrics across the platform.

---

## 7. Settlement Reconciliation

Check merchant settlement status and variance between expected and actual amounts.

```sql
SELECT
    settlement_date,
    merchant_id,
    expected_amount,
    actual_amount,
    variance_pct,
    status
FROM gold.settlement_reconciliation
LIMIT 10;
```

**Expected:** Settlement records with variance percentages. Status values: `matched`, `unmatched`, `pending`.

---

## 8. SCD Type 2 -- Merchant Credit Limit History

View slowly changing dimension snapshots for merchant credit limits.

```sql
SELECT
    merchant_id,
    credit_limit,
    risk_tier,
    dbt_valid_from,
    dbt_valid_to
FROM silver.snapshot_merchant_credit_limits
LIMIT 10;
```

**Expected:** Historical credit limit changes with validity periods. Rows with `dbt_valid_to = NULL` represent the current state.

---

## 9. Drift Metrics -- All Features

View feature drift scores computed by the drift detection DAG.

```sql
SELECT
    feature_name,
    drift_score,
    baseline_median,
    current_median,
    measured_at
FROM feature_store.drift_metrics
ORDER BY feature_name;
```

**Expected:** One row per feature with drift scores. Scores > 0.1 indicate significant drift.

---

## 10. FinOps -- Storage by Database

Check disk usage across all ClickHouse databases for cost monitoring.

```sql
SELECT
    database,
    formatReadableSize(sum(bytes_on_disk)) AS size,
    count() AS parts
FROM system.parts
WHERE active
GROUP BY database
ORDER BY sum(bytes_on_disk) DESC;
```

**Expected:** Bronze largest (raw CDC data), Silver next (deduplicated), Gold smallest (aggregated).

---

## 11. User Cohorts -- LTV by Cohort Month

Analyze user lifetime value grouped by signup cohort.

```sql
SELECT
    cohort_month,
    count() AS users,
    avg(ltv) AS avg_ltv,
    avg(retention_months) AS avg_retention
FROM gold.user_cohorts
GROUP BY cohort_month;
```

**Expected:** Monthly cohorts with increasing LTV for older cohorts (more transaction history).

---

## 12. Delete Audit Log -- Financial Deletes

Audit trail for any delete operations on financial tables (regulatory compliance).

```sql
SELECT
    source_table,
    count() AS delete_count
FROM silver.delete_audit_log
GROUP BY source_table;
```

**Expected:** Minimal or zero deletes on financial tables. Non-zero counts warrant investigation.

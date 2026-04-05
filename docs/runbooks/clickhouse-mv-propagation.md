# ClickHouse Materialized View Propagation

## Behavior

ClickHouse Materialized Views (MVs) trigger **on INSERT**, not on SELECT. Any direct INSERT into a table with an attached MV will immediately propagate through the MV to the target table.

This means:
- Chaos testing INSERTs into Bronze `_raw` tables will also appear in Silver tables
- Data fix scripts that INSERT corrected rows will propagate through MVs
- Seed data re-runs will duplicate data in downstream tables
- Cleanup must cover **both** the source table AND any MV target tables

## Bronze to Silver MV Pairs

| Bronze Source Table | MV Name | Silver Target Table |
|---------------------|---------|---------------------|
| bronze.pg_transactions_raw | silver.mv_bronze_to_silver_tx | silver.transactions_silver |
| bronze.pg_repayments_raw | silver.mv_bronze_to_silver_repay | silver.repayments_silver |
| bronze.pg_users_raw | silver.mv_bronze_to_silver_users | silver.users_silver |
| bronze.pg_merchants_raw | silver.mv_bronze_to_silver_merchants | silver.merchants_silver |
| bronze.pg_installments_raw | silver.mv_bronze_to_silver_install | silver.installments_silver |
| bronze.mongo_app_events_raw | silver.mv_bronze_to_silver_events | silver.app_events_silver |
| bronze.mongo_merchant_sessions_raw | silver.mv_bronze_to_silver_sessions | silver.merchant_sessions_silver |

## Audit MVs (also trigger on Bronze INSERT)

| Bronze Source | MV Name | Target |
|--------------|---------|--------|
| bronze.pg_*_raw (WHERE __op='u') | silver.mv_update_audit_* | silver.update_audit_log |
| bronze.pg_*_raw (WHERE __op='d') | silver.mv_delete_audit_* | silver.delete_audit_log |

## Implications for Chaos Testing

When injecting test data into Bronze tables:
1. The row will appear in both Bronze AND the corresponding Silver table
2. Cleanup requires `ALTER TABLE ... DELETE` on **both** Bronze and Silver
3. Wait ~5 seconds after DELETE mutations before verifying row counts
4. Silver tables using ReplacingMergeTree may retain rows until background merge — use `FINAL` in verification queries

## Safe Testing Pattern

```sql
-- Inject into Bronze
INSERT INTO bronze.pg_transactions_raw VALUES (...);

-- Verify propagation
SELECT count() FROM silver.transactions_silver WHERE transaction_id = 999999;

-- Cleanup BOTH layers
ALTER TABLE bronze.pg_transactions_raw DELETE WHERE transaction_id = 999999;
ALTER TABLE silver.transactions_silver DELETE WHERE transaction_id = 999999;
```

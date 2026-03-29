
        
  
    
    
    
        
        insert into `gold`.`merchant_daily_kpis__dbt_tmp`
        ("merchant_id", "merchant_category", "date", "gmv", "transaction_count", "approved_count", "declined_count", "approval_rate", "avg_basket_size", "bnpl_penetration")

SELECT
    merchant_id,
    merchant_category,
    toDate(created_at) AS date,
    sum(amount) AS gmv,
    toUInt32(count()) AS transaction_count,
    toUInt32(countIf(status = 'approved')) AS approved_count,
    toUInt32(countIf(status = 'declined')) AS declined_count,
    if(count() > 0, countIf(status = 'approved') / count(), 0) AS approval_rate,
    if(count() > 0, sum(amount) / count(), toDecimal64(0, 2)) AS avg_basket_size,
    if(count() > 0, countIf(installment_count > 1) / count(), 0) AS bnpl_penetration
FROM `silver`.`int_transaction_enriched` te

GROUP BY merchant_id, merchant_category, toDate(created_at)
  
    
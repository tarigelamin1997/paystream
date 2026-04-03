-- Gold: merchant_daily_kpis should contain all 200 merchants
-- severity: warn (completeness check, not blocking)


SELECT 1
WHERE (SELECT count(DISTINCT merchant_id) FROM `gold`.`merchant_daily_kpis`) < 200
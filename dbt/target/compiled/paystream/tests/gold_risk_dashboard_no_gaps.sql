-- Gold: risk_dashboard should have continuous daily records (no date gaps)
-- severity: warn (surface missing days without blocking)


SELECT 1
WHERE (
    SELECT dateDiff('day', min(date), max(date)) + 1 - count(DISTINCT date)
    FROM `gold`.`risk_dashboard`
) > 0
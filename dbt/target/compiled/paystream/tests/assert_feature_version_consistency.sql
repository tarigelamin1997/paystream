-- All features for same (user_id, snapshot_ts) must have same feature_version
-- Catches partial feature pipeline failures
-- Note: returns 0 rows until Phase 4 populates Feature Store
SELECT user_id, snapshot_ts, count(DISTINCT feature_version) AS version_count
FROM feature_store.user_credit_features
GROUP BY user_id, snapshot_ts
HAVING version_count > 1
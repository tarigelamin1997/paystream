-- 01_create_databases.sql
-- Create all databases used by the OrderFlow pipeline.
-- Safe to re-run: uses IF NOT EXISTS.

CREATE DATABASE IF NOT EXISTS bronze;
CREATE DATABASE IF NOT EXISTS silver;
CREATE DATABASE IF NOT EXISTS gold;
CREATE DATABASE IF NOT EXISTS feature_store;

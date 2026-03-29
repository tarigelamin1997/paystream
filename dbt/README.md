# PayStream dbt Project

dbt transformation layer for the PayStream BNPL Data Platform.

## Layers

- **Staging (ephemeral):** Thin wrappers — FINAL, cast, filter
- **Intermediate (views):** Join-heavy denormalizations
- **Marts (incremental):** Gold aggregates with delete+insert strategy
- **Snapshots:** SCD Type 2 for merchant limits and user credit tiers

## Run

```bash
# SSH tunnel to ClickHouse
ssh -L 9000:CH_PRIVATE_IP:9000 -i ~/.ssh/paystream-bastion.pem ec2-user@BASTION_EIP -N &

# Install dependencies
dbt deps

# Seed static data
dbt seed

# Snapshot current state
dbt snapshot

# Build all models + run tests
dbt build
```

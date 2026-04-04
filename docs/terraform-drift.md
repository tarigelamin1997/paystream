# Terraform State Drift

## Status: Acknowledged — DO NOT APPLY

## Summary

`terraform plan` shows `4 to add, 3 to change, 4 to destroy`.

The 4 destroys are **EC2 instance replacements** (bastion + ClickHouse) which would destroy all data. These are caused by Terraform version mismatch, NOT by actual infrastructure changes.

## Root Cause

- **Local Terraform:** 1.14.3
- **Project constraint:** `>= 1.7.0` (relaxed from `>= 1.7.0, < 1.8.0` during Phase 7)
- **State written by:** Terraform 1.7.5

Provider plugin versions and internal resource schemas differ between 1.7 and 1.14, causing Terraform to see "changes" that don't exist in the actual infrastructure.

## Affected Resources

| Resource | Action | Risk |
|----------|--------|------|
| `module.bastion.aws_instance.bastion` | **must be replaced** | CRITICAL — destroys bastion EC2 |
| `module.bastion.aws_eip_association.bastion` | **must be replaced** | CRITICAL — loses Elastic IP binding |
| `module.clickhouse.aws_instance.clickhouse` | **must be replaced** | CRITICAL — destroys ClickHouse + all data |
| `module.ecs.aws_ecs_task_definition.fastapi` | **must be replaced** | MEDIUM — recreates task def |
| `module.ecs.aws_ecs_service.fastapi` | update in-place | LOW — service config |
| `module.rds.aws_db_instance.main` | update in-place | LOW — tag/config update |
| `module.vpc.aws_security_group.ecs` | update in-place | LOW — ingress rule |

## Impact

- **No functional impact** on running infrastructure
- All Phase 7 additions (Lambda, API Gateway, IAM) were applied via targeted `-target` applies
- Data pipeline correctness is unaffected

## Resolution Path

1. Pin Terraform version to 1.7.5 in CI/CD and local development
2. Run `terraform init -upgrade` with matching version
3. Apply full plan only in a maintenance window with data backup
4. Never run `terraform apply` without `-target` until versions are aligned

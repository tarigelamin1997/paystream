# PayStream — Real-Time BNPL Data Platform & Feature Store

Real-time CDC pipeline and feature store for Buy Now Pay Later (BNPL) data, built on AWS managed services.

## Architecture

- **Sources:** RDS PostgreSQL 15, DocumentDB 6.0
- **CDC:** Debezium 2.7 on ECS Fargate (separate PG and Mongo connectors)
- **Streaming:** MSK Serverless (IAM + SCRAM-SHA-512 dual auth)
- **Schema Registry:** Confluent Schema Registry 7.6.1 on ECS Fargate
- **OLAP:** ClickHouse 24.8 on EC2 (Bronze/Silver/Gold layers)
- **Batch:** EMR Serverless (Spark 3.5.1 + Delta Lake 3.2.0)
- **Orchestration:** MWAA (Airflow 2.10.0)
- **Observability:** Amazon Managed Grafana + Prometheus

## Region

`eu-north-1` (Stockholm), single AZ (`eu-north-1a`).

**Production improvement:** Multi-AZ with 3 subnets per tier, HA NAT gateway, cross-AZ RDS replica.

## Prerequisites

- AWS CLI configured with credentials for `eu-north-1`
- Terraform 1.7.x
- Docker (for Debezium image builds)
- SSH key pair for bastion access

## Quick Start

```bash
make init          # terraform init
make plan          # terraform plan
make apply         # terraform apply (15-25 min)
make push-images   # Build + push Debezium images to ECR
make seed          # Seed RDS + DocumentDB with synthetic data
make apply-bronze-ddl    # Apply ClickHouse Bronze DDL
make register-connectors # Register Debezium connectors
make verify-phase1       # Run 12-check validation
```

## Component Versions

All versions are declared in `versions.yaml` — the single source of truth.

## Access

All services are in private subnets. Access via SSH tunnel through bastion host:

```bash
ssh -i ~/.ssh/paystream-bastion.pem -L 9000:CLICKHOUSE_PRIVATE_IP:9000 ec2-user@BASTION_EIP
```

## Cost

Phase 1 steady-state: ~$0.80/hour (~$3.20 per 4-hour session).

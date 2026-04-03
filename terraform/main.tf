# PayStream — Root Terraform Module
# Phase 1: Infrastructure + CDC

module "vpc" {
  source = "./modules/vpc"

  project_name           = var.project_name
  environment            = var.environment
  vpc_cidr               = var.vpc_cidr
  public_subnet_cidr     = var.public_subnet_cidr
  private_subnet_cidr    = var.private_subnet_cidr
  private_subnet_1b_cidr = var.private_subnet_1b_cidr
  az_primary             = var.az_primary
  az_secondary           = var.az_secondary
  bastion_allowed_cidr   = var.bastion_allowed_cidr
}

module "iam" {
  source = "./modules/iam"

  project_name    = var.project_name
  environment     = var.environment
  aws_region      = var.aws_region
  msk_cluster_arn = module.msk.cluster_arn
  s3_bucket_arns  = module.s3.bucket_arns
}

module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
}

module "rds" {
  source = "./modules/rds"

  project_name       = var.project_name
  environment        = var.environment
  instance_class     = var.rds_instance_class
  allocated_storage  = var.rds_allocated_storage
  master_username    = var.rds_master_username
  subnet_ids         = [module.vpc.private_subnet_id, module.vpc.private_subnet_1b_id]
  security_group_ids = [module.vpc.rds_sg_id]
}

module "documentdb" {
  source = "./modules/documentdb"

  project_name       = var.project_name
  environment        = var.environment
  instance_class     = var.documentdb_instance_class
  subnet_ids         = [module.vpc.private_subnet_id, module.vpc.private_subnet_1b_id]
  security_group_ids = [module.vpc.docdb_sg_id]
}

module "msk" {
  source = "./modules/msk"

  project_name       = var.project_name
  environment        = var.environment
  subnet_ids         = [module.vpc.private_subnet_id, module.vpc.private_subnet_1b_id]
  security_group_ids = [module.vpc.msk_sg_id]
  vpc_id             = module.vpc.vpc_id
}

module "ecs" {
  source = "./modules/ecs"

  project_name             = var.project_name
  environment              = var.environment
  aws_region               = var.aws_region
  vpc_id                   = module.vpc.vpc_id
  private_subnet_ids       = [module.vpc.private_subnet_id]
  ecs_sg_ids               = [module.vpc.ecs_sg_id, module.vpc.private_sg_id]
  msk_bootstrap_brokers    = module.msk.bootstrap_brokers_iam
  rds_endpoint             = module.rds.endpoint
  rds_db_name              = module.rds.db_name
  rds_secret_arn           = module.rds.master_secret_arn
  documentdb_endpoint      = module.documentdb.cluster_endpoint
  documentdb_secret_arn    = module.documentdb.master_secret_arn
  debezium_pg_cpu          = var.debezium_pg_cpu
  debezium_pg_memory       = var.debezium_pg_memory
  debezium_mongo_cpu       = var.debezium_mongo_cpu
  debezium_mongo_memory    = var.debezium_mongo_memory
  schema_registry_cpu      = var.schema_registry_cpu
  schema_registry_memory   = var.schema_registry_memory
  debezium_pg_role_arn     = module.iam.ecs_debezium_pg_role_arn
  debezium_mongo_role_arn  = module.iam.ecs_debezium_mongo_role_arn
  schema_registry_role_arn = module.iam.ecs_schema_registry_role_arn
  ecs_execution_role_arn   = module.iam.ecs_execution_role_arn
  # Phase 5 — FastAPI
  clickhouse_private_ip    = module.clickhouse.private_ip
  fastapi_task_role_arn    = module.iam.ecs_fastapi_role_arn
  public_subnet_ids        = module.vpc.public_subnet_ids
}

module "clickhouse" {
  source = "./modules/clickhouse"

  project_name       = var.project_name
  environment        = var.environment
  instance_type      = var.clickhouse_instance_type
  ebs_size           = var.clickhouse_ebs_size
  subnet_id          = module.vpc.private_subnet_id
  security_group_ids = [module.vpc.clickhouse_sg_id, module.vpc.private_sg_id]
  key_name           = var.bastion_key_name
}

module "emr" {
  source = "./modules/emr"

  project_name         = var.project_name
  environment          = var.environment
  subnet_ids           = [module.vpc.private_subnet_id]
  security_group_ids   = [module.vpc.private_sg_id]
  emr_execution_role_arn = module.iam.emr_execution_role_arn
}

module "mwaa" {
  source = "./modules/mwaa"

  project_name           = var.project_name
  environment            = var.environment
  environment_class      = var.mwaa_environment_class
  subnet_ids             = [module.vpc.private_subnet_id, module.vpc.private_subnet_1b_id]
  security_group_ids     = [module.vpc.private_sg_id]
  dags_bucket_arn        = module.s3.mwaa_dags_bucket_arn
  dags_bucket_name       = module.s3.mwaa_dags_bucket_name
  mwaa_execution_role_arn = module.iam.mwaa_execution_role_arn
}

module "observability" {
  source = "./modules/observability"

  project_name            = var.project_name
  environment             = var.environment
  alert_email             = var.alert_email
  slack_webhook_url       = var.slack_webhook_url
  rds_instance_identifier = "${var.project_name}-rds"
}

module "bastion" {
  source = "./modules/bastion"

  project_name    = var.project_name
  environment     = var.environment
  instance_type   = var.bastion_instance_type
  subnet_id       = module.vpc.public_subnet_id
  security_group_ids = [module.vpc.bastion_sg_id]
  key_name        = var.bastion_key_name
}

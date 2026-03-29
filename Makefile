# === Phase 1: Infrastructure + CDC ===
init:
	cd terraform && terraform init
plan:
	cd terraform && terraform plan -var-file=environments/dev.tfvars
apply:
	cd terraform && terraform apply -var-file=environments/dev.tfvars -auto-approve
destroy:
	cd terraform && terraform destroy -var-file=environments/dev.tfvars -auto-approve
build-debezium-pg:
	cd debezium/docker && docker build -f Dockerfile.debezium-pg -t paystream-debezium-pg:latest .
build-debezium-mongo:
	cd debezium/docker && docker build -f Dockerfile.debezium-mongo -t paystream-debezium-mongo:latest .
push-images: build-debezium-pg build-debezium-mongo
	# ECR login, tag, push for both images
	bash scripts/push_images.sh
seed:
	bash scripts/seed_data.sh
apply-bronze-ddl:
	bash scripts/apply_clickhouse_ddl.sh
register-connectors:
	bash scripts/register_connectors.sh
run-phase1: apply push-images seed apply-bronze-ddl register-connectors verify-phase1
verify-phase1:
	bash scripts/verify_phase1.sh

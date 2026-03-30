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

# === Phase 2: ClickHouse DWH ===
apply-silver-ddl:
	bash scripts/apply_silver_ddl.sh
apply-gold-ddl:
	bash scripts/apply_gold_ddl.sh
apply-feature-ddl:
	bash scripts/apply_feature_store_ddl.sh
verify-phase2:
	bash scripts/verify_phase2.sh

# === Phase 3: dbt Transformation Layer ===
verify-phase3:
	bash scripts/verify_phase3.sh

# === Phase 4: Feature Store ===
compute-features:
	python3 scripts/compute_features.py
verify-phase4:
	bash scripts/verify_phase4.sh

# === Phase 5: Feature API + Airflow DAGs ===
sync-dags:
	bash scripts/sync_dags.sh
verify-phase5:
	bash scripts/verify_phase5.sh

# === Phase 6: Observability + Stress Test + Docs ===
provision-grafana:
	bash scripts/provision_grafana.sh
stress-test:
	bash scripts/stress_test.sh
verify-phase6:
	bash scripts/verify_phase6.sh

# === Composite Targets ===
preflight:
	@echo "=== PayStream Preflight Check ==="
	terraform -version
	aws sts get-caller-identity
	docker info > /dev/null 2>&1 && echo "Docker: OK" || echo "Docker: NOT RUNNING"
	python3 --version
	@echo "=== Preflight Complete ==="

deploy: init apply push-images apply-bronze-ddl apply-silver-ddl apply-gold-ddl apply-feature-ddl register-connectors
	@echo "=== Full deployment complete ==="

pipeline: compute-features
	@echo "=== Pipeline complete ==="

teardown:
	bash scripts/teardown.sh

verify-clean:
	@echo "=== Verifying clean teardown ==="
	cd terraform && terraform state list 2>/dev/null | wc -l | xargs -I{} echo "Remaining resources: {}"
	@echo "=== Verify clean complete ==="

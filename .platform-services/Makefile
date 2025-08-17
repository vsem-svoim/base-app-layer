.PHONY: help init validate deploy clean test

help:
	@echo "FinPortIQ Platform Management"
	@echo ""
	@echo "Commands:"
	@echo "  init         - Initialize project structure"
	@echo "  validate     - Validate configurations"
	@echo "  deploy       - Deploy platform (ENV=dev PROVIDER=aws)"
	@echo "  clean        - Clean resources"
	@echo "  test         - Run tests"

init:
	@echo "Project structure initialized"

validate:
	@echo "Validating configurations..."
	./scripts/testing/run-tests.sh

deploy:
	@ENV ?= dev
	@PROVIDER ?= aws
	@REGION ?= us-east-1
	./scripts/deployment/deploy.sh $(ENV) $(PROVIDER) $(REGION)

clean:
	@ENV ?= dev
	@echo "Cleaning resources in $(ENV)..."
	cd terraform/environments/$(ENV) && terraform destroy -auto-approve

test:
	./scripts/testing/run-tests.sh

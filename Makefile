.PHONY: help init plan apply destroy fmt validate clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform
	terraform init

plan: ## Show what changes will be made
	terraform plan

apply: ## Apply changes to Grafana
	terraform apply

destroy: ## Destroy all Grafana resources (USE WITH CAUTION)
	terraform destroy

fmt: ## Format all Terraform files
	terraform fmt -recursive

validate: ## Validate Terraform configuration
	terraform validate

clean: ## Clean Terraform cache and state
	rm -rf .terraform
	rm -f .terraform.lock.hcl

setup: ## First-time setup (copy config and init)
	@if [ ! -f terraform.tfvars ]; then \
		cp terraform.tfvars.example terraform.tfvars; \
		echo "Created terraform.tfvars - please edit it with your values"; \
	else \
		echo "terraform.tfvars already exists"; \
	fi
	@$(MAKE) init

quick-deploy: fmt validate apply ## Format, validate, and deploy in one command

check: fmt validate plan ## Format, validate, and show plan

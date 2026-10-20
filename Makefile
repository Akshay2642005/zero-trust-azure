TF_DIR := envs/dev
MODULES := $(wildcard modules/*)

.PHONY: help init fmt fmt-check validate validate-modules test lint security hooks check plan apply destroy up down

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+( [a-zA-Z_-]+)*:.*?##/ {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Install providers/modules and configure the backend
	@terraform -chdir=$(TF_DIR) init

fmt: ## Format all Terraform files
	@terraform fmt -recursive

fmt-check: ## Fail if any file is not formatted
	@terraform fmt -recursive -check

validate: ## Validate the environment configuration
	@terraform -chdir=$(TF_DIR) validate

validate-modules: ## Validate every module without a backend
	@for m in $(MODULES); do \
		echo "==> $$m"; \
		terraform -chdir=$$m init -backend=false -input=false >/dev/null && \
		terraform -chdir=$$m validate || exit 1; \
	done

test: ## Run offline terraform tests in every module
	@for m in $(MODULES); do \
		echo "==> $$m"; \
		terraform -chdir=$$m init -backend=false -input=false >/dev/null && \
		terraform -chdir=$$m test || exit 1; \
	done

lint: ## Run tflint across the repository
	@tflint --init
	@tflint --recursive --format compact

security: ## Run Checkov with the justified-skip config
	@checkov -d . --config-file .checkov.yaml

hooks: ## Install the pre-commit hooks
	@command -v pre-commit >/dev/null || { echo "pre-commit is not installed: brew install pre-commit terraform-docs"; exit 1; }
	@pre-commit install

check: fmt-check validate-modules test lint security ## Run every local gate

plan: ## Show the pending changes
	@terraform -chdir=$(TF_DIR) plan

apply: ## Apply the pending changes
	@terraform -chdir=$(TF_DIR) apply

destroy: ## Destroy the environment
	@terraform -chdir=$(TF_DIR) destroy

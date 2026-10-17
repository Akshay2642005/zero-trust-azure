TF_DIR := envs/dev

.PHONY: help init fmt fmt-check validate plan apply destroy up down

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+( [a-zA-Z_-]+)*:.*?##/ {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Install providers/modules and configure the backend
	@terraform -chdir=$(TF_DIR) init

fmt: ## Format all Terraform files
	@terraform fmt -recursive

fmt-check: ## Fail if any file is not formatted
	@terraform fmt -recursive -check

validate: ## Validate the environment configuration
	@terraform -chdir=$(TF_DIR) validate

plan: ## Show the pending changes
	@terraform -chdir=$(TF_DIR) plan

apply up: ## Apply the pending changes
	@terraform -chdir=$(TF_DIR) apply

destroy down: ## Destroy the environment
	@terraform -chdir=$(TF_DIR) destroy

# Remote state and runs are managed by HCP Terraform (Terraform Cloud).
#
# 1. Set `organization` below to your HCP Terraform organization.
# 2. Run `terraform login` once, then `terraform init` from this directory.
# 3. Create the workspace (or let `terraform init` create it) and provide Azure
#    credentials to it as workspace environment variables:
#      ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
#
# The subscription_id variable remains the source of truth for the target
# subscription; the remaining ARM_* values authenticate the provider.
terraform {
  cloud {
    organization = "YOUR-TFC-ORG"

    workspaces {
      name = "zero-trust-azure-dev"
    }
  }
}

# Remote state and runs are managed by HCP Terraform (Terraform Cloud).
#
# 1. Set `organization` below to your HCP Terraform organization.
# 2. Run `terraform login` once, then `terraform init` from this directory.
# 3. Create the workspace (or let `terraform init` create it). Give it Azure
#    credentials as workspace environment variables. This project uses dynamic
#    provider credentials (OIDC) rather than a stored secret:
#      TFC_AZURE_PROVIDER_AUTH=true
#      TFC_AZURE_RUN_CLIENT_ID=<app registration client id>
#      ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
#    scripts/setup-oidc.rb configures all of this for you.
#
# The subscription_id variable remains the source of truth for the target
# subscription; the ARM_* values authenticate the provider.
terraform {
  cloud {
    organization = "akshay2642005"

    workspaces {
      name = "zero-trust-azure-dev"
    }
  }
}

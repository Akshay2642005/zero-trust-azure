resource "azurerm_resource_group" "this" {
  name       = local.resource_group_name
  location   = var.location
  managed_by = "terraform"
  tags       = local.common_tags
}

module "network" {
  source  = "app.terraform.io/akshay2642005/network/azurerm"
  version = "1.2.0"

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  naming              = local.network_naming

  hub_address_space             = var.hub_address_space
  spoke_address_space           = var.spoke_address_space
  hub_default_subnet_prefix     = var.hub_default_subnet_prefix
  hub_access_subnet_prefix      = var.hub_access_subnet_prefix
  spoke_workload_subnet_prefix  = var.spoke_workload_subnet_prefix
  spoke_pe_subnet_prefix        = var.spoke_pe_subnet_prefix
  spoke2_address_space          = var.spoke2_address_space
  spoke2_workload_subnet_prefix = var.spoke2_workload_subnet_prefix
  allow_forwarded_traffic       = var.allow_forwarded_traffic

  # Temporary F5 exception (ADR-006). The rule exists only while NAT is the
  # connector's egress path; Phase 6 replaces it with firewall FQDN rules.
  allow_hub_access_internet_443 = var.deploy_egress_nat

  tags = local.common_tags
}

# Controlled egress for the hub-access subnet. Off by default because the NAT
# Gateway and its public IP are billable (roughly $35-40/month). Enable with
# deploy_egress_nat = true when the Twingate connector is deployed (Phase 3).
module "egress" {
  source  = "app.terraform.io/akshay2642005/egress/azurerm"
  version = "0.1.0"
  count   = var.deploy_egress_nat ? 1 : 0

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  naming              = local.egress_naming
  subnet_id           = module.network.hub_access_subnet_id

  tags = local.common_tags
}

module "storage" {
  source  = "app.terraform.io/akshay2642005/storage/azurerm"
  version = "1.0.0"

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  naming              = local.storage_naming

  pe_subnet_id = module.network.spoke_pe_subnet_id
  vnet_id      = module.network.spoke_vnet_id

  tags = local.common_tags
}

module "policy" {
  source   = "app.terraform.io/akshay2642005/policy/azurerm"
  version  = "1.1.0"
  for_each = local.policy_assignments

  name                 = each.key
  resource_group_id    = azurerm_resource_group.this.id
  policy_definition_id = each.value.definition_id
  custom_definition    = each.value.custom_definition
  parameters           = each.value.parameters

  display_name = each.value.display_name
  description  = each.value.description
  enforce      = each.value.enforce
}

module "deny_public_ip_on_nic" {
  source  = "app.terraform.io/akshay2642005/policy/azurerm"
  version = "1.1.0"

  name                 = local.deny_public_ip_on_nic_name
  resource_group_id    = azurerm_resource_group.this.id
  policy_definition_id = local.deny_public_ip_on_nic_definition_id

  display_name = "Deny Public IPs on Network Interfaces"
  description  = "Zero Trust: prevent network interfaces from having public IPs attached."
  enforce      = true
}

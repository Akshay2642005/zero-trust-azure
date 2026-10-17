resource "azurerm_resource_group" "this" {
  name       = local.resource_group_name
  location   = var.location
  managed_by = "terraform"
  tags       = local.common_tags
}

module "network" {
  source = "../../modules/network"

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  naming              = local.network_naming

  hub_address_space            = var.hub_address_space
  spoke_address_space          = var.spoke_address_space
  hub_default_subnet_prefix    = var.hub_default_subnet_prefix
  spoke_workload_subnet_prefix = var.spoke_workload_subnet_prefix
  spoke_pe_subnet_prefix       = var.spoke_pe_subnet_prefix
  allow_forwarded_traffic      = var.allow_forwarded_traffic

  tags = local.common_tags
}

module "storage" {
  source = "../../modules/storage"

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  naming              = local.storage_naming

  pe_subnet_id = module.network.spoke_pe_subnet_id
  vnet_id      = module.network.spoke_vnet_id

  tags = local.common_tags
}

module "deny_public_ip_on_nic" {
  source = "../../modules/policy"

  name                 = local.deny_public_ip_on_nic_name
  resource_group_id    = azurerm_resource_group.this.id
  policy_definition_id = local.deny_public_ip_on_nic_definition_id

  display_name = "Deny Public IPs on Network Interfaces"
  description  = "Zero Trust: prevent network interfaces from having public IPs attached."
  enforce      = true
}

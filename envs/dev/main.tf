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

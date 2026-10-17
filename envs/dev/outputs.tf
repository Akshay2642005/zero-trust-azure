output "resource_group_name" {
  description = "Name of the resource group holding the environment."
  value       = azurerm_resource_group.this.name
}

output "hub_vnet_id" {
  description = "Resource ID of the hub virtual network."
  value       = module.network.hub_vnet_id
}

output "spoke_vnet_id" {
  description = "Resource ID of the spoke virtual network."
  value       = module.network.spoke_vnet_id
}

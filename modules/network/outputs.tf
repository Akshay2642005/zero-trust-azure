output "hub_vnet_id" {
  description = "Resource ID of the hub virtual network."
  value       = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  description = "Name of the hub virtual network."
  value       = azurerm_virtual_network.hub.name
}

output "spoke_vnet_id" {
  description = "Resource ID of the spoke virtual network."
  value       = azurerm_virtual_network.spoke.id
}

output "spoke_vnet_name" {
  description = "Name of the spoke virtual network."
  value       = azurerm_virtual_network.spoke.name
}

output "spoke2_vnet_id" {
  description = "Resource ID of the second spoke virtual network."
  value       = azurerm_virtual_network.spoke2.id
}

output "spoke2_vnet_name" {
  description = "Name of the second spoke virtual network."
  value       = azurerm_virtual_network.spoke2.name
}

output "hub_default_subnet_id" {
  description = "Resource ID of the hub default subnet."
  value       = azurerm_subnet.hub_default.id
}

output "hub_access_subnet_id" {
  description = "Resource ID of the hub access subnet."
  value       = azurerm_subnet.hub_access.id
}

output "hub_access_nsg_id" {
  description = "Resource ID of the hub access network security group."
  value       = azurerm_network_security_group.hub_access.id
}

output "spoke_workload_subnet_id" {
  description = "Resource ID of the spoke workload subnet."
  value       = azurerm_subnet.spoke_workload.id
}

output "spoke_pe_subnet_id" {
  description = "Resource ID of the spoke private-endpoints subnet."
  value       = azurerm_subnet.spoke_pe.id
}

output "spoke2_workload_subnet_id" {
  description = "Resource ID of the second spoke workload subnet."
  value       = azurerm_subnet.spoke2_workload.id
}

output "hub_nsg_id" {
  description = "Resource ID of the hub network security group."
  value       = azurerm_network_security_group.hub.id
}

output "spoke_nsg_id" {
  description = "Resource ID of the spoke network security group."
  value       = azurerm_network_security_group.spoke.id
}

output "spoke2_nsg_id" {
  description = "Resource ID of the second spoke network security group."
  value       = azurerm_network_security_group.spoke2.id
}

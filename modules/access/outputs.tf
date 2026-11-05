output "connector_vm_id" {
  description = "Resource ID of the connector VM."
  value       = azurerm_linux_virtual_machine.connector.id
}

output "connector_private_ip" {
  description = "Private IP address of the connector VM in the hub-access subnet."
  value       = azurerm_network_interface.connector.private_ip_address
}

output "connector_identity_principal_id" {
  description = "Principal ID of the connector VM's system-assigned managed identity."
  value       = azurerm_linux_virtual_machine.connector.identity[0].principal_id
}

output "remote_network_id" {
  description = "Twingate remote network ID."
  value       = twingate_remote_network.this.id
}

output "connector_id" {
  description = "Twingate connector ID."
  value       = twingate_connector.this.id
}

output "twingate_resource_ids" {
  description = "Map of Twingate resource names to their IDs."
  value       = { for k, v in twingate_resource.this : k => v.id }
}

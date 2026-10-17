output "storage_account_id" {
  description = "Resource ID of the storage account."
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "Name of the storage account."
  value       = azurerm_storage_account.this.name
}

output "private_dns_zone_id" {
  description = "Resource ID of the blob private DNS zone."
  value       = azurerm_private_dns_zone.this.id
}

output "private_endpoint_id" {
  description = "Resource ID of the blob private endpoint."
  value       = azurerm_private_endpoint.this.id
}

output "private_endpoint_ip" {
  description = "Private IP address allocated to the blob private endpoint."
  value       = azurerm_private_endpoint.this.private_service_connection[0].private_ip_address
}

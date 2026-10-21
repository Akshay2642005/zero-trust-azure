output "nat_public_ip" {
  description = "Public IP address used as the source address for outbound NAT flows."
  value       = azurerm_public_ip.this.ip_address
}

output "nat_public_ip_id" {
  description = "Resource ID of the NAT Gateway public IP."
  value       = azurerm_public_ip.this.id
}

output "nat_gateway_id" {
  description = "Resource ID of the NAT Gateway."
  value       = azurerm_nat_gateway.this.id
}

output "subnet_id" {
  description = "Resource ID of the subnet associated with the NAT Gateway."
  value       = azurerm_subnet_nat_gateway_association.this.subnet_id
}

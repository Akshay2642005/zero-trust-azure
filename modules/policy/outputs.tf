output "id" {
  description = "Resource ID of the policy assignment."
  value       = azurerm_resource_group_policy_assignment.this.id
}

output "name" {
  description = "Name of the policy assignment."
  value       = azurerm_resource_group_policy_assignment.this.name
}

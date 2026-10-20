output "id" {
  description = "Resource ID of the policy assignment."
  value       = azurerm_resource_group_policy_assignment.this.id
}

output "name" {
  description = "Name of the policy assignment."
  value       = azurerm_resource_group_policy_assignment.this.name
}

output "definition_id" {
  description = "Resource ID of the policy definition that was assigned (built-in or custom)."
  value       = local.definition_id
}

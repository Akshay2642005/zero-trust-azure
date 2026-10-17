resource "azurerm_resource_group_policy_assignment" "this" {
  name                 = var.name
  resource_group_id    = var.resource_group_id
  policy_definition_id = var.policy_definition_id
  display_name         = var.display_name
  description          = var.description
  enforce              = var.enforce
}

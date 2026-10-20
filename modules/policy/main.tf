resource "azurerm_policy_definition" "custom" {
  count = var.custom_definition == null ? 0 : 1

  name         = var.custom_definition.name
  policy_type  = "Custom"
  mode         = var.custom_definition.mode
  display_name = var.custom_definition.display_name
  description  = var.custom_definition.description
  policy_rule  = var.custom_definition.policy_rule
  metadata     = var.custom_definition.metadata
}

locals {
  definition_id = var.custom_definition == null ? var.policy_definition_id : azurerm_policy_definition.custom[0].id
}

resource "azurerm_resource_group_policy_assignment" "this" {
  name                 = var.name
  resource_group_id    = var.resource_group_id
  policy_definition_id = local.definition_id
  display_name         = var.display_name
  description          = var.description
  enforce              = var.enforce
  parameters           = var.parameters == null ? null : jsonencode(var.parameters)
}

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.81.0, < 5.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.81.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_policy_definition.custom](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/policy_definition) | resource |
| [azurerm_resource_group_policy_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group_policy_assignment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Name of the policy assignment (unique within the scope). | `string` | n/a | yes |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | Resource ID of the resource group the policy is assigned to (the scope). | `string` | n/a | yes |
| <a name="input_custom_definition"></a> [custom\_definition](#input\_custom\_definition) | Optional custom policy definition to create and assign. Set this or policy\_definition\_id, not both. | <pre>object({<br/>    name         = string<br/>    display_name = string<br/>    description  = optional(string)<br/>    mode         = optional(string, "All")<br/>    policy_rule  = string<br/>    metadata     = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of what the assignment enforces. | `string` | `null` | no |
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | Human-readable display name for the assignment. | `string` | `null` | no |
| <a name="input_enforce"></a> [enforce](#input\_enforce) | Whether the policy is enforced (false stores it as a non-enforced audit). | `bool` | `true` | no |
| <a name="input_parameters"></a> [parameters](#input\_parameters) | Policy parameter values. Rendered to the JSON string the assignment expects. | `any` | `null` | no |
| <a name="input_policy_definition_id"></a> [policy\_definition\_id](#input\_policy\_definition\_id) | Resource ID of an existing policy definition or initiative to assign. Set this or custom\_definition, not both. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_definition_id"></a> [definition\_id](#output\_definition\_id) | Resource ID of the policy definition that was assigned (built-in or custom). |
| <a name="output_id"></a> [id](#output\_id) | Resource ID of the policy assignment. |
| <a name="output_name"></a> [name](#output\_name) | Name of the policy assignment. |
<!-- END_TF_DOCS -->
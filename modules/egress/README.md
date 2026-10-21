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
| [azurerm_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway) | resource |
| [azurerm_nat_gateway_public_ip_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway_public_ip_association) | resource |
| [azurerm_public_ip.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_subnet_nat_gateway_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_nat_gateway_association) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the NAT Gateway and its public IP. | `string` | n/a | yes |
| <a name="input_naming"></a> [naming](#input\_naming) | Physical names for every resource this module creates. | <pre>object({<br/>    nat_gateway   = string<br/>    nat_public_ip = string<br/>  })</pre> | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group that holds the egress resources. | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Resource ID of the subnet that gets outbound internet access through the NAT Gateway. | `string` | n/a | yes |
| <a name="input_idle_timeout_in_minutes"></a> [idle\_timeout\_in\_minutes](#input\_idle\_timeout\_in\_minutes) | TCP idle timeout for flows through the NAT Gateway, in minutes. | `number` | `4` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource that supports them. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_nat_gateway_id"></a> [nat\_gateway\_id](#output\_nat\_gateway\_id) | Resource ID of the NAT Gateway. |
| <a name="output_nat_public_ip"></a> [nat\_public\_ip](#output\_nat\_public\_ip) | Public IP address used as the source address for outbound NAT flows. |
| <a name="output_nat_public_ip_id"></a> [nat\_public\_ip\_id](#output\_nat\_public\_ip\_id) | Resource ID of the NAT Gateway public IP. |
| <a name="output_subnet_id"></a> [subnet\_id](#output\_subnet\_id) | Resource ID of the subnet associated with the NAT Gateway. |
<!-- END_TF_DOCS -->
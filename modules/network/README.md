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
| [azurerm_network_security_group.hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_network_security_group.spoke](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_network_security_group.spoke2](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_subnet.hub_default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.spoke2_workload](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.spoke_pe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.spoke_workload](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.hub_default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_subnet_network_security_group_association.spoke2_workload](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_subnet_network_security_group_association.spoke_workload](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_virtual_network.hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_virtual_network.spoke](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_virtual_network.spoke2](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_virtual_network_peering.hub_to_spoke](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [azurerm_virtual_network_peering.hub_to_spoke2](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [azurerm_virtual_network_peering.spoke2_to_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [azurerm_virtual_network_peering.spoke2_to_spoke](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [azurerm_virtual_network_peering.spoke_to_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [azurerm_virtual_network_peering.spoke_to_spoke2](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_location"></a> [location](#input\_location) | Azure region for every network resource. | `string` | n/a | yes |
| <a name="input_naming"></a> [naming](#input\_naming) | Physical names for every resource this module creates. | <pre>object({<br/>    hub_vnet                = string<br/>    spoke_vnet              = string<br/>    spoke2_vnet             = string<br/>    hub_default_subnet      = string<br/>    spoke_workload_subnet   = string<br/>    spoke_pe_subnet         = string<br/>    spoke2_workload_subnet  = string<br/>    hub_nsg                 = string<br/>    spoke_nsg               = string<br/>    spoke2_nsg              = string<br/>    hub_to_spoke_peering    = string<br/>    spoke_to_hub_peering    = string<br/>    hub_to_spoke2_peering   = string<br/>    spoke2_to_hub_peering   = string<br/>    spoke_to_spoke2_peering = string<br/>    spoke2_to_spoke_peering = string<br/>  })</pre> | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group that holds the network. | `string` | n/a | yes |
| <a name="input_allow_forwarded_traffic"></a> [allow\_forwarded\_traffic](#input\_allow\_forwarded\_traffic) | Whether to allow forwarded traffic across the VNet peerings. | `bool` | `true` | no |
| <a name="input_hub_address_space"></a> [hub\_address\_space](#input\_hub\_address\_space) | Address space (CIDRs) for the hub virtual network. | `list(string)` | <pre>[<br/>  "10.0.0.0/16"<br/>]</pre> | no |
| <a name="input_hub_default_subnet_prefix"></a> [hub\_default\_subnet\_prefix](#input\_hub\_default\_subnet\_prefix) | Address prefix for the hub default subnet. | `string` | `"10.0.1.0/24"` | no |
| <a name="input_nsg_allowlist_exceptions"></a> [nsg\_allowlist\_exceptions](#input\_nsg\_allowlist\_exceptions) | Allow rules that may use a wildcard or Internet address prefix. Every entry is a documented exception; anything not listed here is rejected by the test suite. | <pre>list(object({<br/>    nsg    = string<br/>    rule   = string<br/>    field  = string<br/>    reason = string<br/>  }))</pre> | <pre>[<br/>  {<br/>    "field": "source_address_prefix",<br/>    "nsg": "spoke2",<br/>    "reason": "Outbound rule; the destination is pinned to the spoke workload prefix.",<br/>    "rule": "AllowHttpsToSpoke1Workload"<br/>  }<br/>]</pre> | no |
| <a name="input_spoke2_address_space"></a> [spoke2\_address\_space](#input\_spoke2\_address\_space) | Address space (CIDRs) for the second spoke virtual network. | `list(string)` | <pre>[<br/>  "10.2.0.0/16"<br/>]</pre> | no |
| <a name="input_spoke2_workload_subnet_prefix"></a> [spoke2\_workload\_subnet\_prefix](#input\_spoke2\_workload\_subnet\_prefix) | Address prefix for the second spoke workload subnet. | `string` | `"10.2.0.0/24"` | no |
| <a name="input_spoke_address_space"></a> [spoke\_address\_space](#input\_spoke\_address\_space) | Address space (CIDRs) for the spoke virtual network. | `list(string)` | <pre>[<br/>  "10.1.0.0/16"<br/>]</pre> | no |
| <a name="input_spoke_pe_subnet_prefix"></a> [spoke\_pe\_subnet\_prefix](#input\_spoke\_pe\_subnet\_prefix) | Address prefix for the spoke private-endpoints subnet. | `string` | `"10.1.1.0/24"` | no |
| <a name="input_spoke_workload_subnet_prefix"></a> [spoke\_workload\_subnet\_prefix](#input\_spoke\_workload\_subnet\_prefix) | Address prefix for the spoke workload subnet. | `string` | `"10.1.0.0/24"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource that supports them. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_hub_default_subnet_id"></a> [hub\_default\_subnet\_id](#output\_hub\_default\_subnet\_id) | Resource ID of the hub default subnet. |
| <a name="output_hub_nsg_id"></a> [hub\_nsg\_id](#output\_hub\_nsg\_id) | Resource ID of the hub network security group. |
| <a name="output_hub_vnet_id"></a> [hub\_vnet\_id](#output\_hub\_vnet\_id) | Resource ID of the hub virtual network. |
| <a name="output_hub_vnet_name"></a> [hub\_vnet\_name](#output\_hub\_vnet\_name) | Name of the hub virtual network. |
| <a name="output_spoke2_nsg_id"></a> [spoke2\_nsg\_id](#output\_spoke2\_nsg\_id) | Resource ID of the second spoke network security group. |
| <a name="output_spoke2_vnet_id"></a> [spoke2\_vnet\_id](#output\_spoke2\_vnet\_id) | Resource ID of the second spoke virtual network. |
| <a name="output_spoke2_vnet_name"></a> [spoke2\_vnet\_name](#output\_spoke2\_vnet\_name) | Name of the second spoke virtual network. |
| <a name="output_spoke2_workload_subnet_id"></a> [spoke2\_workload\_subnet\_id](#output\_spoke2\_workload\_subnet\_id) | Resource ID of the second spoke workload subnet. |
| <a name="output_spoke_nsg_id"></a> [spoke\_nsg\_id](#output\_spoke\_nsg\_id) | Resource ID of the spoke network security group. |
| <a name="output_spoke_pe_subnet_id"></a> [spoke\_pe\_subnet\_id](#output\_spoke\_pe\_subnet\_id) | Resource ID of the spoke private-endpoints subnet. |
| <a name="output_spoke_vnet_id"></a> [spoke\_vnet\_id](#output\_spoke\_vnet\_id) | Resource ID of the spoke virtual network. |
| <a name="output_spoke_vnet_name"></a> [spoke\_vnet\_name](#output\_spoke\_vnet\_name) | Name of the spoke virtual network. |
| <a name="output_spoke_workload_subnet_id"></a> [spoke\_workload\_subnet\_id](#output\_spoke\_workload\_subnet\_id) | Resource ID of the spoke workload subnet. |
<!-- END_TF_DOCS -->
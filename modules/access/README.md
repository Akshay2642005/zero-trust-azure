<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.81.0, < 5.0.0 |
| <a name="requirement_twingate"></a> [twingate](#requirement\_twingate) | >= 3.0.0, < 4.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.81.0 |
| <a name="provider_twingate"></a> [twingate](#provider\_twingate) | 3.8.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_dev_test_global_vm_shutdown_schedule.connector](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dev_test_global_vm_shutdown_schedule) | resource |
| [azurerm_linux_virtual_machine.connector](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine) | resource |
| [azurerm_network_interface.connector](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [twingate_connector.this](https://registry.terraform.io/providers/Twingate/twingate/latest/docs/resources/connector) | resource |
| [twingate_connector_tokens.this](https://registry.terraform.io/providers/Twingate/twingate/latest/docs/resources/connector_tokens) | resource |
| [twingate_remote_network.this](https://registry.terraform.io/providers/Twingate/twingate/latest/docs/resources/remote_network) | resource |
| [twingate_resource.this](https://registry.terraform.io/providers/Twingate/twingate/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the connector VM. | `string` | n/a | yes |
| <a name="input_naming"></a> [naming](#input\_naming) | Physical names for every resource this module creates. | <pre>object({<br/>    remote_network = string<br/>    connector      = string<br/>    connector_vm   = string<br/>    vm_nic         = string<br/>    vm_os_disk     = string<br/>  })</pre> | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group that holds the access resources. | `string` | n/a | yes |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | SSH public key for the connector VM admin user. | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Resource ID of the hub-access subnet where the connector VM is placed. | `string` | n/a | yes |
| <a name="input_twingate_network"></a> [twingate\_network](#input\_twingate\_network) | Twingate network name (the subdomain in <name>.twingate.com). | `string` | n/a | yes |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | Admin SSH username for the connector VM. | `string` | `"azureuser"` | no |
| <a name="input_auto_shutdown_time"></a> [auto\_shutdown\_time](#input\_auto\_shutdown\_time) | The daily time in 24-hour format (HHmm) when the VM will automatically shut down (e.g. 2000 for 8:00 PM). | `string` | `"2000"` | no |
| <a name="input_auto_shutdown_timezone"></a> [auto\_shutdown\_timezone](#input\_auto\_shutdown\_timezone) | The time zone for the daily shutdown schedule. | `string` | `"India Standard Time"` | no |
| <a name="input_enable_auto_shutdown"></a> [enable\_auto\_shutdown](#input\_enable\_auto\_shutdown) | Whether to configure an automated daily shutdown schedule for the connector VM to eliminate idle cost. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every Azure resource that supports them. | `map(string)` | `{}` | no |
| <a name="input_twingate_resources"></a> [twingate\_resources](#input\_twingate\_resources) | Map of Twingate resources to create. Each resource defines an address and protocol/port restrictions. | <pre>map(object({<br/>    address = string<br/>    protocols = optional(object({<br/>      allow_icmp = optional(bool, false)<br/>      tcp = optional(object({<br/>        policy = optional(string, "RESTRICTED")<br/>        ports  = optional(list(string), [])<br/>      }), {})<br/>      udp = optional(object({<br/>        policy = optional(string, "DENY_ALL")<br/>        ports  = optional(list(string), [])<br/>      }), {})<br/>    }), {})<br/>    group_ids = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | Azure VM size for the connector. Use a small burstable SKU to minimise cost. | `string` | `"Standard_B1s"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_connector_id"></a> [connector\_id](#output\_connector\_id) | Twingate connector ID. |
| <a name="output_connector_identity_principal_id"></a> [connector\_identity\_principal\_id](#output\_connector\_identity\_principal\_id) | Principal ID of the connector VM's system-assigned managed identity. |
| <a name="output_connector_private_ip"></a> [connector\_private\_ip](#output\_connector\_private\_ip) | Private IP address of the connector VM in the hub-access subnet. |
| <a name="output_connector_vm_id"></a> [connector\_vm\_id](#output\_connector\_vm\_id) | Resource ID of the connector VM. |
| <a name="output_remote_network_id"></a> [remote\_network\_id](#output\_remote\_network\_id) | Twingate remote network ID. |
| <a name="output_twingate_resource_ids"></a> [twingate\_resource\_ids](#output\_twingate\_resource\_ids) | Map of Twingate resource names to their IDs. |
<!-- END_TF_DOCS -->
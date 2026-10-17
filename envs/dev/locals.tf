locals {
  # Single source of truth for the resource group.
  resource_group_name = "zt-rg"

  # Names owned by the network module.
  network_naming = {
    hub_vnet              = "hub-vnet"
    spoke_vnet            = "spoke-vnet"
    hub_default_subnet    = "hub-default"
    spoke_workload_subnet = "spoke-workload"
    spoke_pe_subnet       = "spoke-private-endpoints"
    hub_nsg               = "hub-nsg"
    spoke_nsg             = "spoke-nsg"
    hub_to_spoke_peering  = "hub-to-spoke"
    spoke_to_hub_peering  = "spoke-to-hub"
  }

  # Names owned by the storage module.
  storage_naming = {
    storage_account            = var.storage_account_name
    private_dns_zone           = "privatelink.blob.core.windows.net"
    private_dns_zone_link      = "blob-vnet-link"
    private_endpoint           = "pe-storage-blob"
    private_service_connection = "pe-storage-blob-connection"
    private_dns_zone_group     = "storage-dns-zone-group"
  }

  # Azure Policy built-in "Network interfaces should not have public IPs".
  deny_public_ip_on_nic_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/83a86a26-fd1f-447c-b59d-e51f44264114"

  # Tags applied to every resource that supports them.
  common_tags = merge(
    {
      managed-by  = "terraform"
      project     = "zero-trust-network"
      environment = var.environment
    },
    var.tags,
  )
}

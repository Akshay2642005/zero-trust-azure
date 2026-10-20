# Offline invariant tests for the storage module (T4, T8).

mock_provider "azurerm" {}

variables {
  resource_group_name = "rg-zero-trust-test"
  location            = "eastus"
  pe_subnet_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-zero-trust-test/providers/Microsoft.Network/virtualNetworks/spoke-vnet/subnets/spoke-private-endpoints"
  vnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-zero-trust-test/providers/Microsoft.Network/virtualNetworks/spoke-vnet"

  shared_access_key_enabled = false

  tags = {
    managed-by  = "terraform"
    project     = "zero-trust-network"
    environment = "test"
  }

  naming = {
    storage_account            = "ztteststorage001"
    private_dns_zone           = "privatelink.blob.core.windows.net"
    private_dns_zone_link      = "blob-vnet-link"
    private_endpoint           = "pe-storage-blob"
    private_service_connection = "pe-storage-blob-connection"
    private_dns_zone_group     = "storage-dns-zone-group"
  }
}

run "storage_is_private_and_hardened" {
  command = plan

  assert {
    condition = (
      azurerm_storage_account.this.public_network_access_enabled == false &&
      azurerm_storage_account.this.min_tls_version == "TLS1_2" &&
      azurerm_storage_account.this.allow_nested_items_to_be_public == false &&
      azurerm_storage_account.this.https_traffic_only_enabled == true &&
      azurerm_storage_account.this.shared_access_key_enabled == false
    )

    error_message = "T4: storage must disable public access and shared keys, require TLS 1.2 and keep nested items private."
  }
}

run "required_tags_on_storage_resources" {
  command = plan

  assert {
    condition = alltrue([
      for resource in [
        azurerm_storage_account.this,
        azurerm_private_dns_zone.this,
        azurerm_private_dns_zone_virtual_network_link.this,
        azurerm_private_endpoint.this,
        ] : alltrue([
          for key in ["managed-by", "project", "environment"] : contains(keys(resource.tags), key)
      ])
    ])

    error_message = "T8: every taggable storage resource must carry managed-by, project and environment."
  }
}

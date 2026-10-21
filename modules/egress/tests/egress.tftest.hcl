# Offline invariant tests for the egress module.
#
# The azurerm provider is mocked and every run uses `command = plan`, so this
# suite needs no Azure credentials and creates no resources.

mock_provider "azurerm" {}

variables {
  resource_group_name = "rg-zero-trust-test"
  location            = "eastus"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-zero-trust-test/providers/Microsoft.Network/virtualNetworks/hub-vnet/subnets/hub-access"

  naming = {
    nat_gateway   = "hub-access-nat"
    nat_public_ip = "hub-access-nat-ip"
  }

  tags = {
    managed-by  = "terraform"
    project     = "zero-trust-network"
    environment = "test"
  }
}

run "public_ip_is_standard_and_static" {
  command = plan

  assert {
    condition = (
      azurerm_public_ip.this.sku == "Standard" &&
      azurerm_public_ip.this.allocation_method == "Static"
    )

    error_message = "NAT needs a Standard, static public IP; the Basic SKU cannot be associated with a NAT Gateway."
  }
}

run "nat_gateway_is_standard" {
  command = plan

  assert {
    condition = azurerm_nat_gateway.this.sku_name == "Standard"

    error_message = "The NAT Gateway must use the Standard SKU."
  }
}

run "nat_is_associated_only_with_the_supplied_subnet" {
  command = plan

  assert {
    condition = azurerm_subnet_nat_gateway_association.this.subnet_id == var.subnet_id

    error_message = "The NAT Gateway association must target the supplied subnet."
  }
}

run "required_tags_on_egress_resources" {
  command = plan

  assert {
    condition = alltrue([
      for resource in [
        azurerm_public_ip.this,
        azurerm_nat_gateway.this,
        ] : alltrue([
          for key in ["managed-by", "project", "environment"] : contains(keys(resource.tags), key)
      ])
    ])

    error_message = "T8: every taggable egress resource must carry managed-by, project and environment."
  }
}

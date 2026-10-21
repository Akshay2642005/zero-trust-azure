# Offline invariant tests for the network module (T1, T2, T3, T7, T8).
#
# The azurerm provider is mocked and every run uses `command = plan`, so this
# suite needs no Azure credentials and creates no resources.

mock_provider "azurerm" {}

variables {
  resource_group_name = "rg-zero-trust-test"
  location            = "eastus"

  tags = {
    managed-by  = "terraform"
    project     = "zero-trust-network"
    environment = "test"
  }

  naming = {
    hub_vnet                = "hub-vnet"
    spoke_vnet              = "spoke-vnet"
    spoke2_vnet             = "spoke2-vnet"
    hub_default_subnet      = "hub-default"
    spoke_workload_subnet   = "spoke-workload"
    spoke_pe_subnet         = "spoke-private-endpoints"
    spoke2_workload_subnet  = "spoke2-workload"
    hub_nsg                 = "hub-nsg"
    spoke_nsg               = "spoke-nsg"
    spoke2_nsg              = "spoke2-nsg"
    hub_to_spoke_peering    = "hub-to-spoke"
    spoke_to_hub_peering    = "spoke-to-hub"
    hub_to_spoke2_peering   = "hub-to-spoke2"
    spoke2_to_hub_peering   = "spoke2-to-hub"
    spoke_to_spoke2_peering = "spoke-to-spoke2"
    spoke2_to_spoke_peering = "spoke2-to-spoke"
  }
}

run "deny_all_rules_present" {
  command = plan

  assert {
    condition = alltrue([
      for nsg in [
        azurerm_network_security_group.hub,
        azurerm_network_security_group.hub_access,
        azurerm_network_security_group.spoke,
        azurerm_network_security_group.spoke2,
        ] : alltrue([
          for required in ["DenyAllInbound", "DenyAllOutbound"] : anytrue([
            for rule in nsg.security_rule :
            rule.name == required &&
            rule.access == "Deny" &&
            rule.priority == 4096 &&
            rule.direction == (required == "DenyAllInbound" ? "Inbound" : "Outbound")
          ])
      ])
    ])

    error_message = "T1: every NSG must keep DenyAllInbound and DenyAllOutbound at priority 4096."
  }
}

run "wildcard_allow_rules_are_allowlisted" {
  command = plan

  assert {
    condition = alltrue([
      for item in flatten([
        for nsg_name, nsg in {
          hub        = azurerm_network_security_group.hub
          hub_access = azurerm_network_security_group.hub_access
          spoke      = azurerm_network_security_group.spoke
          spoke2     = azurerm_network_security_group.spoke2
          } : [
          for rule in nsg.security_rule : {
            nsg  = nsg_name
            rule = rule
          }
        ]
        ]) : (
        item.rule.access != "Allow" ||
        (!contains(["*", "0.0.0.0/0", "Internet"], item.rule.source_address_prefix) &&
        !contains(["*", "0.0.0.0/0", "Internet"], item.rule.destination_address_prefix)) ||
        (item.nsg == "spoke2" &&
          item.rule.name == "AllowHttpsToSpoke1Workload" &&
          item.rule.source_address_prefix == "*" &&
        item.rule.destination_address_prefix == "10.1.0.0/24")
      )
    ])

    error_message = "T2: only the documented AllowHttpsToSpoke1Workload rule may use a wildcard address prefix."
  }
}

run "management_ports_not_open_to_the_internet" {
  command = plan

  assert {
    condition = alltrue([
      for item in flatten([
        for nsg_name, nsg in {
          hub        = azurerm_network_security_group.hub
          hub_access = azurerm_network_security_group.hub_access
          spoke      = azurerm_network_security_group.spoke
          spoke2     = azurerm_network_security_group.spoke2
          } : [
          for rule in nsg.security_rule : {
            nsg  = nsg_name
            rule = rule
          }
        ]
        ]) : (
        item.rule.access != "Allow" ||
        !contains(["22", "3389"], item.rule.destination_port_range) ||
        startswith(item.rule.source_address_prefix, "10.")
      )
    ])

    error_message = "T3: no NSG may allow inbound SSH or RDP from a non-internal source."
  }
}

run "required_tags_on_network_resources" {
  command = plan

  assert {
    condition = alltrue([
      for resource in [
        azurerm_virtual_network.hub,
        azurerm_virtual_network.spoke,
        azurerm_virtual_network.spoke2,
        azurerm_network_security_group.hub,
        azurerm_network_security_group.hub_access,
        azurerm_network_security_group.spoke,
        azurerm_network_security_group.spoke2,
        ] : alltrue([
          for key in ["managed-by", "project", "environment"] : contains(keys(resource.tags), key)
      ])
    ])

    error_message = "T8: every taggable network resource must carry managed-by, project and environment."
  }
}

run "hub_access_subnet_is_created" {
  command = plan

  assert {
    condition = (
      azurerm_subnet.hub_access.name == "hub-access" &&
      contains(azurerm_subnet.hub_access.address_prefixes, "10.0.4.0/27") &&
      length(azurerm_subnet.hub_access.address_prefixes) == 1 &&
      azurerm_network_security_group.hub_access.name == "hub-access-nsg"
    )

    error_message = "R2.1: hub-access must be created as 10.0.4.0/27 with its own NSG."
  }
}

run "temporary_internet_rule_is_off_by_default" {
  command = plan

  assert {
    condition = length([
      for rule in azurerm_network_security_group.hub_access.security_rule : rule
      if rule.name == "AllowHttpsToInternet"
    ]) == 0

    error_message = "F5 must not exist unless allow_hub_access_internet_443 is enabled."
  }
}

run "temporary_internet_rule_when_enabled" {
  command = plan

  variables {
    allow_hub_access_internet_443 = true
  }

  assert {
    condition = length([
      for rule in azurerm_network_security_group.hub_access.security_rule : rule
      if(
        rule.name == "AllowHttpsToInternet" &&
        rule.priority == 100 &&
        rule.direction == "Outbound" &&
        rule.access == "Allow" &&
        rule.protocol == "Tcp" &&
        rule.destination_port_range == "443" &&
        rule.source_address_prefix == "10.0.4.0/27" &&
        rule.destination_address_prefix == "Internet"
      )
    ]) == 1

    error_message = "R2.3: the temporary F5 rule must allow exactly TCP/443 from 10.0.4.0/27 to Internet."
  }
}

run "overlapping_vnet_address_spaces_fail" {
  command = plan

  variables {
    spoke2_address_space = ["10.1.128.0/17"]
  }

  expect_failures = [azurerm_virtual_network.hub]
}

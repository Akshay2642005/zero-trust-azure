locals {
  # Zero-trust default-deny: every NSG drops all inbound and all outbound
  # traffic unless a higher-priority rule explicitly allows it.
  deny_all_rules = {
    DenyAllInbound = {
      direction = "Inbound"
      priority  = 4096
    }
    DenyAllOutbound = {
      direction = "Outbound"
      priority  = 4096
    }
  }
}

# --- Network Security Groups ---

resource "azurerm_network_security_group" "hub" {
  name                = var.naming.hub_nsg
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = local.deny_all_rules

    content {
      name                       = security_rule.key
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_network_security_group" "spoke" {
  name                = var.naming.spoke_nsg
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = local.deny_all_rules

    content {
      name                       = security_rule.key
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  # The one carefully crafted allow rule: spoke2 may reach spoke1's workload
  # subnet over HTTPS. Everything else on this NSG stays default-deny.
  security_rule {
    name                       = "AllowHttpsFromSpoke2"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.spoke2_workload_subnet_prefix
    destination_address_prefix = var.spoke_workload_subnet_prefix
  }
}

resource "azurerm_network_security_group" "spoke2" {
  name                = var.naming.spoke2_nsg
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = local.deny_all_rules

    content {
      name                       = security_rule.key
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  # The same allow rule, expressed as egress from spoke2. Without this the
  # default-deny outbound rule would drop the packet before it leaves.
  security_rule {
    name                       = "AllowHttpsToSpoke1Workload"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = var.spoke_workload_subnet_prefix
  }
}

# --- Virtual networks ---

resource "azurerm_virtual_network" "hub" {
  name                = var.naming.hub_vnet
  address_space       = var.hub_address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_virtual_network" "spoke" {
  name                = var.naming.spoke_vnet
  address_space       = var.spoke_address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_virtual_network" "spoke2" {
  name                = var.naming.spoke2_vnet
  address_space       = var.spoke2_address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# --- Subnets ---

resource "azurerm_subnet" "hub_default" {
  name                 = var.naming.hub_default_subnet
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_default_subnet_prefix]
}

resource "azurerm_subnet" "spoke_workload" {
  name                 = var.naming.spoke_workload_subnet
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.spoke_workload_subnet_prefix]
}

# The private-endpoints subnet is left open (no NSG) so that private link
# traffic is not dropped before it reaches the endpoint.
resource "azurerm_subnet" "spoke_pe" {
  name                 = var.naming.spoke_pe_subnet
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.spoke_pe_subnet_prefix]
}

resource "azurerm_subnet" "spoke2_workload" {
  name                 = var.naming.spoke2_workload_subnet
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke2.name
  address_prefixes     = [var.spoke2_workload_subnet_prefix]
}

# --- Subnet ↔ NSG associations ---

resource "azurerm_subnet_network_security_group_association" "hub_default" {
  subnet_id                 = azurerm_subnet.hub_default.id
  network_security_group_id = azurerm_network_security_group.hub.id
}

resource "azurerm_subnet_network_security_group_association" "spoke_workload" {
  subnet_id                 = azurerm_subnet.spoke_workload.id
  network_security_group_id = azurerm_network_security_group.spoke.id
}

resource "azurerm_subnet_network_security_group_association" "spoke2_workload" {
  subnet_id                 = azurerm_subnet.spoke2_workload.id
  network_security_group_id = azurerm_network_security_group.spoke2.id
}

# --- Bidirectional peering ---

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = var.naming.hub_to_spoke_peering
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic   = var.allow_forwarded_traffic
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = var.naming.spoke_to_hub_peering
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = var.allow_forwarded_traffic
}

resource "azurerm_virtual_network_peering" "hub_to_spoke2" {
  name                      = var.naming.hub_to_spoke2_peering
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke2.id
  allow_forwarded_traffic   = var.allow_forwarded_traffic
}

resource "azurerm_virtual_network_peering" "spoke2_to_hub" {
  name                      = var.naming.spoke2_to_hub_peering
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.spoke2.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = var.allow_forwarded_traffic
}

# Direct spoke-to-spoke peering. Hub-and-spoke alone does not route between
# spokes without an NVA, so this pair is what actually carries the HTTPS flow.
resource "azurerm_virtual_network_peering" "spoke_to_spoke2" {
  name                      = var.naming.spoke_to_spoke2_peering
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = azurerm_virtual_network.spoke2.id
  allow_forwarded_traffic   = var.allow_forwarded_traffic
}

resource "azurerm_virtual_network_peering" "spoke2_to_spoke" {
  name                      = var.naming.spoke2_to_spoke_peering
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.spoke2.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic   = var.allow_forwarded_traffic
}

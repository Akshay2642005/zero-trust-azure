# Controlled outbound internet access for a single subnet.
#
# New VNets have no implicit outbound internet access. The Twingate connector
# initiates outbound connections to Twingate's cloud and accepts no inbound
# traffic, so a NAT Gateway is the minimum viable egress path. The public IP is
# an outbound SNAT address: it is attached to the NAT Gateway, not to a NIC or
# a VM, and it does not make the subnet reachable from the internet.

resource "azurerm_public_ip" "this" {
  name                = var.naming.nat_public_ip
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "this" {
  name                    = var.naming.nat_gateway
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = var.idle_timeout_in_minutes
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.this.id
}

# Exactly one subnet is associated. The module is instantiated per egress
# subnet, so a second subnet cannot silently inherit this NAT Gateway.
resource "azurerm_subnet_nat_gateway_association" "this" {
  subnet_id      = var.subnet_id
  nat_gateway_id = azurerm_nat_gateway.this.id
}

# --- Twingate remote network and connector ---

resource "twingate_remote_network" "this" {
  name = var.naming.remote_network
}

resource "twingate_connector" "this" {
  remote_network_id = twingate_remote_network.this.id
  name              = var.naming.connector
}

resource "twingate_connector_tokens" "this" {
  connector_id = twingate_connector.this.id
}

# --- Connector VM ---
#
# The connector runs on a small Ubuntu LTS VM in the hub-access subnet.
# It has no public IP (T5), authenticates with SSH public key only, and
# installs the Twingate connector service via cloud-init using the tokens
# generated above.
#
# ADR-003: tokens are passed via custom_data (cloud-init) in Phase 3.
# Phase 4 replaces this with a Key Vault fetch via managed identity.

resource "azurerm_network_interface" "connector" {
  name                = var.naming.vm_nic
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "connector" {
  name                            = var.naming.connector_vm
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  allow_extension_operations      = false
  network_interface_ids           = [azurerm_network_interface.connector.id]
  tags                            = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = var.naming.vm_os_disk
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # ADR-003: cloud-init installs and configures the Twingate connector.
  # The tokens are sensitive and exist in state (HCP Terraform, encrypted).
  # Phase 4 moves them to Key Vault.
  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init.yaml", {
    access_token  = twingate_connector_tokens.this.access_token
    refresh_token = twingate_connector_tokens.this.refresh_token
    network       = var.twingate_network
  }))

  identity {
    type = "SystemAssigned"
  }
}

# --- Cost optimization: automated shutdown ---
#
# Prevents idle compute charges by shutting down the connector VM daily.
# Running standard LRS deallocated VM costs only pennies for disk storage.
resource "azurerm_dev_test_global_vm_shutdown_schedule" "connector" {
  count = var.enable_auto_shutdown ? 1 : 0

  virtual_machine_id = azurerm_linux_virtual_machine.connector.id
  location           = var.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.auto_shutdown_timezone

  notification_settings {
    enabled = false
  }

  tags = var.tags
}

# --- Twingate resources ---
#
# Each resource maps a private address to a set of Twingate groups.
# The connector resolves and proxies traffic to these addresses.

resource "twingate_resource" "this" {
  for_each = var.twingate_resources

  name              = each.key
  address           = each.value.address
  remote_network_id = twingate_remote_network.this.id

  protocols = {
    allow_icmp = each.value.protocols.allow_icmp

    tcp = {
      policy = each.value.protocols.tcp.policy
      ports  = each.value.protocols.tcp.ports
    }

    udp = {
      policy = each.value.protocols.udp.policy
      ports  = each.value.protocols.udp.ports
    }
  }

  dynamic "access_group" {
    for_each = each.value.group_ids
    content {
      group_id = access_group.value
    }
  }
}

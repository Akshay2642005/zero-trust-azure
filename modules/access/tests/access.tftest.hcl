mock_provider "azurerm" {}
mock_provider "twingate" {}

variables {
  resource_group_name = "test-rg"
  location            = "eastus"
  naming = {
    remote_network = "test-remote-network"
    connector      = "test-connector"
    connector_vm   = "test-connector-vm"
    vm_nic         = "test-connector-nic"
    vm_os_disk     = "test-connector-disk"
  }
  subnet_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
  ssh_public_key   = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCwENp05qddigvAnggJbRFJMiM47DxI7YFitLBaPzZdLl1GUnocaHGijbMY3do8+SzGR3igbkTp2LK3URZe9aec1L5ShZwrsEpfCKMCrA0SteKRyp69uIJR1zNEOc3QkPtSKN37XUlLsHdGbTlOzCtKifjU7QAhRewwhDAy68M2qC2VnCewx8QtJY4HbmeyyqBBvu8fzx0j4ceiPHicBdXvd4+iC3a/5YHqfY9ThVCYTV6NgVxqWzj2uyS7FfjmaxOllXYzuwUFNPugcoPFKp9LG03t1CllfmqJdGd1NOzSU65G0N1QTVEQTQ0kyXwz9PyL2NOeTTHlWDi1aaScgy43 test@example.com"
  twingate_network = "example"
  tags = {
    managed-by  = "terraform"
    project     = "zero-trust-network"
    environment = "dev"
  }
}

# T5: no public IP on the connector VM or NIC
run "connector_has_no_public_ip" {
  command = plan

  assert {
    condition     = azurerm_network_interface.connector.ip_configuration[0].public_ip_address_id == null
    error_message = "The connector network interface must not have a public IP attached (T5)."
  }
}

# Connector VM requires SSH key auth and has password auth disabled
run "connector_disables_password_auth" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine.connector.disable_password_authentication == true
    error_message = "The connector VM must enforce SSH key authentication only."
  }
}

# Tagging invariant (T8)
run "required_tags_on_access_resources" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine.connector.tags["managed-by"] == "terraform" && azurerm_linux_virtual_machine.connector.tags["project"] == "zero-trust-network" && azurerm_linux_virtual_machine.connector.tags["environment"] == "dev"
    error_message = "Connector VM must carry the standard tags (T8)."
  }

  assert {
    condition     = azurerm_network_interface.connector.tags["managed-by"] == "terraform" && azurerm_network_interface.connector.tags["project"] == "zero-trust-network" && azurerm_network_interface.connector.tags["environment"] == "dev"
    error_message = "Connector NIC must carry the standard tags (T8)."
  }
}

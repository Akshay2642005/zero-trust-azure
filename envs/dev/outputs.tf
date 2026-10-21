output "resource_group_name" {
  description = "Name of the resource group holding the environment."
  value       = azurerm_resource_group.this.name
}

output "hub_vnet_id" {
  description = "Resource ID of the hub virtual network."
  value       = module.network.hub_vnet_id
}

output "spoke_vnet_id" {
  description = "Resource ID of the spoke virtual network."
  value       = module.network.spoke_vnet_id
}

output "spoke2_vnet_id" {
  description = "Resource ID of the second spoke virtual network."
  value       = module.network.spoke2_vnet_id
}

output "hub_access_subnet_id" {
  description = "Resource ID of the hub access subnet that hosts the Twingate connector."
  value       = module.network.hub_access_subnet_id
}

output "hub_access_nsg_id" {
  description = "Resource ID of the hub access network security group."
  value       = module.network.hub_access_nsg_id
}

output "nat_public_ip" {
  description = "Outbound public IP of the NAT Gateway, or null when deploy_egress_nat is false."
  value       = one(module.egress[*].nat_public_ip)
}

output "storage_account_name" {
  description = "Name of the storage account."
  value       = module.storage.storage_account_name
}

output "storage_private_endpoint_id" {
  description = "Resource ID of the blob private endpoint."
  value       = module.storage.private_endpoint_id
}

output "storage_private_endpoint_ip" {
  description = "Private IP address allocated to the blob private endpoint."
  value       = module.storage.private_endpoint_ip
}

output "policy_assignment_id" {
  description = "Resource ID of the deny-public-IP-on-NIC policy assignment."
  value       = module.deny_public_ip_on_nic.id
}

output "policy_assignment_ids" {
  description = "Resource IDs of every Phase 1 policy assignment, keyed by assignment name."
  value = merge(
    { deny-public-ip-on-nic = module.deny_public_ip_on_nic.id },
    { for name, assignment in module.policy : name => assignment.id },
  )
}

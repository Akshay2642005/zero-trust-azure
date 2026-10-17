variable "resource_group_name" {
  description = "Name of the resource group that holds the network."
  type        = string
}

variable "location" {
  description = "Azure region for every network resource."
  type        = string
}

variable "naming" {
  description = "Physical names for every resource this module creates."

  type = object({
    hub_vnet              = string
    spoke_vnet            = string
    hub_default_subnet    = string
    spoke_workload_subnet = string
    spoke_pe_subnet       = string
    hub_nsg               = string
    spoke_nsg             = string
    hub_to_spoke_peering  = string
    spoke_to_hub_peering  = string
  })
}

variable "hub_address_space" {
  description = "Address space (CIDRs) for the hub virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "spoke_address_space" {
  description = "Address space (CIDRs) for the spoke virtual network."
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "hub_default_subnet_prefix" {
  description = "Address prefix for the hub default subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "spoke_workload_subnet_prefix" {
  description = "Address prefix for the spoke workload subnet."
  type        = string
  default     = "10.1.0.0/24"
}

variable "spoke_pe_subnet_prefix" {
  description = "Address prefix for the spoke private-endpoints subnet."
  type        = string
  default     = "10.1.1.0/24"
}

variable "allow_forwarded_traffic" {
  description = "Whether to allow forwarded traffic across the VNet peerings."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource that supports them."
  type        = map(string)
  default     = {}
}

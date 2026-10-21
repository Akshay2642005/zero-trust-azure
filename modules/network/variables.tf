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
    hub_vnet                = string
    spoke_vnet              = string
    spoke2_vnet             = string
    hub_default_subnet      = string
    hub_access_subnet       = optional(string, "hub-access")
    spoke_workload_subnet   = string
    spoke_pe_subnet         = string
    spoke2_workload_subnet  = string
    hub_nsg                 = string
    hub_access_nsg          = optional(string, "hub-access-nsg")
    spoke_nsg               = string
    spoke2_nsg              = string
    hub_to_spoke_peering    = string
    spoke_to_hub_peering    = string
    hub_to_spoke2_peering   = string
    spoke2_to_hub_peering   = string
    spoke_to_spoke2_peering = string
    spoke2_to_spoke_peering = string
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

variable "hub_access_subnet_prefix" {
  description = "Address prefix for the hub access subnet that hosts the Twingate connector."
  type        = string
  default     = "10.0.4.0/27"

  validation {
    condition     = can(cidrhost(var.hub_access_subnet_prefix, 0))
    error_message = "hub_access_subnet_prefix must be a valid IPv4 CIDR."
  }
}

variable "allow_hub_access_internet_443" {
  description = "Temporary F5 exception: allow TCP/443 from the hub access subnet to the Internet. Enabled only while the NAT Gateway is the connector's egress path; replaced by Azure Firewall FQDN rules in Phase 6 (ADR-006)."
  type        = bool
  default     = false
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

variable "spoke2_address_space" {
  description = "Address space (CIDRs) for the second spoke virtual network."
  type        = list(string)
  default     = ["10.2.0.0/16"]
}

variable "spoke2_workload_subnet_prefix" {
  description = "Address prefix for the second spoke workload subnet."
  type        = string
  default     = "10.2.0.0/24"
}

variable "allow_forwarded_traffic" {
  description = "Whether to allow forwarded traffic across the VNet peerings."
  type        = bool
  default     = true
}

variable "nsg_allowlist_exceptions" {
  description = "Allow rules that may use a wildcard or Internet address prefix. Every entry is a documented exception; anything not listed here is rejected by the test suite."

  type = list(object({
    nsg    = string
    rule   = string
    field  = string
    reason = string
  }))

  default = [
    {
      nsg    = "spoke2"
      rule   = "AllowHttpsToSpoke1Workload"
      field  = "source_address_prefix"
      reason = "Outbound rule; the destination is pinned to the spoke workload prefix."
    },
    {
      nsg    = "hub_access"
      rule   = "AllowHttpsToInternet"
      field  = "destination_address_prefix"
      reason = "TEMP F5 (ADR-006): connector egress to Twingate while the NAT Gateway is the path. Removed in Phase 6 when Firewall FQDN rules land."
    },
  ]
}

variable "tags" {
  description = "Tags applied to every resource that supports them."
  type        = map(string)
  default     = {}
}

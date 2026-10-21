variable "subscription_id" {
  description = "Azure subscription ID that will hold the resources."
  type        = string
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name used in the common tags."
  type        = string
  default     = "dev"
}

variable "storage_account_name" {
  description = "Globally unique storage account name (3-24 lowercase alphanumerics)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 characters, lowercase letters and numbers only."
  }
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
}

variable "deploy_egress_nat" {
  description = "Whether to deploy the NAT Gateway and temporary F5 egress exception for the hub access subnet. Billable (~$35-40/month)."
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

variable "tags" {
  description = "Additional tags merged into the common tags."
  type        = map(string)
  default     = {}
}

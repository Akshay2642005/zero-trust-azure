variable "resource_group_name" {
  description = "Name of the resource group that holds the storage resources."
  type        = string
}

variable "location" {
  description = "Azure region for the storage resources."
  type        = string
}

variable "naming" {
  description = "Physical names for every resource this module creates."

  type = object({
    storage_account            = string
    private_dns_zone           = string
    private_dns_zone_link      = string
    private_endpoint           = string
    private_service_connection = string
    private_dns_zone_group     = string
  })
}

variable "pe_subnet_id" {
  description = "Resource ID of the subnet the private endpoint's NIC is created in."
  type        = string
}

variable "vnet_id" {
  description = "Resource ID of the virtual network linked to the private DNS zone."
  type        = string
}

variable "account_tier" {
  description = "Storage account performance tier."
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "Storage account replication strategy (LRS, ZRS, GRS, RAGRS)."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"], var.account_replication_type)
    error_message = "account_replication_type must be one of LRS, ZRS, GRS, RAGRS, GZRS or RAGZRS."
  }
}

variable "shared_access_key_enabled" {
  description = "Whether shared-key (account key) access is permitted. Disable for AAD-only access."
  type        = bool
  default     = true
}

variable "blob_soft_delete_days" {
  description = "Number of days soft-deleted blobs are retained."
  type        = number
  default     = 7
}

variable "container_soft_delete_days" {
  description = "Number of days soft-deleted containers are retained."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags applied to every resource that supports them."
  type        = map(string)
  default     = {}
}

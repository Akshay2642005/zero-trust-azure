variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "storage_account_name" {
  description = "Globally unique name for the storage account (3-24 chars, lowercase letters and numbers only)"
  type        = string
}

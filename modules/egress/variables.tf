variable "resource_group_name" {
  description = "Name of the resource group that holds the egress resources."
  type        = string
}

variable "location" {
  description = "Azure region for the NAT Gateway and its public IP."
  type        = string
}

variable "naming" {
  description = "Physical names for every resource this module creates."

  type = object({
    nat_gateway   = string
    nat_public_ip = string
  })
}

variable "subnet_id" {
  description = "Resource ID of the subnet that gets outbound internet access through the NAT Gateway."
  type        = string
}

variable "idle_timeout_in_minutes" {
  description = "TCP idle timeout for flows through the NAT Gateway, in minutes."
  type        = number
  default     = 4

  validation {
    condition     = var.idle_timeout_in_minutes >= 4 && var.idle_timeout_in_minutes <= 120
    error_message = "idle_timeout_in_minutes must be between 4 and 120."
  }
}

variable "tags" {
  description = "Tags applied to every resource that supports them."
  type        = map(string)
  default     = {}
}

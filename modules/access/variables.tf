variable "resource_group_name" {
  description = "Name of the resource group that holds the access resources."
  type        = string
}

variable "location" {
  description = "Azure region for the connector VM."
  type        = string
}

variable "naming" {
  description = "Physical names for every resource this module creates."

  type = object({
    remote_network = string
    connector      = string
    connector_vm   = string
    vm_nic         = string
    vm_os_disk     = string
  })
}

variable "subnet_id" {
  description = "Resource ID of the hub-access subnet where the connector VM is placed."
  type        = string
}

variable "vm_size" {
  description = "Azure VM size for the connector. Use a small burstable SKU to minimise cost."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin SSH username for the connector VM."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for the connector VM admin user."
  type        = string
}

variable "twingate_network" {
  description = "Twingate network name (the subdomain in <name>.twingate.com)."
  type        = string
}

variable "twingate_resources" {
  description = "Map of Twingate resources to create. Each resource defines an address and protocol/port restrictions."

  type = map(object({
    address = string
    protocols = optional(object({
      allow_icmp = optional(bool, false)
      tcp = optional(object({
        policy = optional(string, "RESTRICTED")
        ports  = optional(list(string), [])
      }), {})
      udp = optional(object({
        policy = optional(string, "DENY_ALL")
        ports  = optional(list(string), [])
      }), {})
    }), {})
    group_ids = list(string)
  }))

  default = {}
}

variable "enable_auto_shutdown" {
  description = "Whether to configure an automated daily shutdown schedule for the connector VM to eliminate idle cost."
  type        = bool
  default     = true
}

variable "auto_shutdown_time" {
  description = "The daily time in 24-hour format (HHmm) when the VM will automatically shut down (e.g. 2000 for 8:00 PM)."
  type        = string
  default     = "2000"
}

variable "auto_shutdown_timezone" {
  description = "The time zone for the daily shutdown schedule."
  type        = string
  default     = "India Standard Time"
}

variable "tags" {
  description = "Tags applied to every Azure resource that supports them."
  type        = map(string)
  default     = {}
}

variable "name" {
  description = "Name of the policy assignment (unique within the scope)."
  type        = string
}

variable "resource_group_id" {
  description = "Resource ID of the resource group the policy is assigned to (the scope)."
  type        = string
}

variable "policy_definition_id" {
  description = "Resource ID of the policy definition or initiative to assign."
  type        = string
}

variable "display_name" {
  description = "Human-readable display name for the assignment."
  type        = string
  default     = null
}

variable "description" {
  description = "Description of what the assignment enforces."
  type        = string
  default     = null
}

variable "enforce" {
  description = "Whether the policy is enforced (false stores it as a non-enforced audit)."
  type        = bool
  default     = true
}

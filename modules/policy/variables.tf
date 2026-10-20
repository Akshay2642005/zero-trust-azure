variable "name" {
  description = "Name of the policy assignment (unique within the scope)."
  type        = string
}

variable "resource_group_id" {
  description = "Resource ID of the resource group the policy is assigned to (the scope)."
  type        = string
}

variable "policy_definition_id" {
  description = "Resource ID of an existing policy definition or initiative to assign. Set this or custom_definition, not both."
  type        = string
  default     = null

  validation {
    condition     = (var.policy_definition_id != null) != (var.custom_definition != null)
    error_message = "Set exactly one of policy_definition_id or custom_definition."
  }
}

variable "custom_definition" {
  description = "Optional custom policy definition to create and assign. Set this or policy_definition_id, not both."

  type = object({
    name         = string
    display_name = string
    description  = optional(string)
    mode         = optional(string, "All")
    policy_rule  = string
    metadata     = optional(string)
  })

  default = null
}

variable "parameters" {
  description = "Policy parameter values. Rendered to the JSON string the assignment expects."
  type        = any
  default     = null
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

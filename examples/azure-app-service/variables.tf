variable "auth_client_id" {
  type        = string
  default     = null
  description = "Entra ID app registration client ID."
}

variable "auth_client_secret" {
  type        = string
  default     = null
  sensitive   = true
  description = "Entra ID app registration client secret."
}

variable "auth_tenant_id" {
  type        = string
  default     = null
  description = "Entra ID tenant ID."
}

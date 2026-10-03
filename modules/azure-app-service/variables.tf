# ---------------------------------------------------------------------------
# Placement and naming
# ---------------------------------------------------------------------------
variable "app_name" {
  type        = string
  description = "Name of the web app. Lowercased by the module (App Service requires a globally unique lowercase name)."
}

variable "plan_name" {
  type        = string
  description = "Name of the App Service plan."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to deploy into."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource the module creates."
}

# ---------------------------------------------------------------------------
# Plan and runtime
# ---------------------------------------------------------------------------
variable "os_type" {
  type        = string
  default     = "Windows"
  description = "Plan operating system: \"Windows\" or \"Linux\"."
}

variable "sku_name" {
  type        = string
  default     = "P1v3"
  description = "App Service plan SKU, e.g. \"P1v3\"."
}

variable "node_version" {
  type        = string
  default     = "20-lts"
  description = "Node.js runtime version for the application stack."
}

variable "minimum_tls_version" {
  type        = string
  default     = "1.2"
  description = "Minimum inbound TLS version."
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "vnet_integration_subnet_id" {
  type        = string
  default     = null
  description = "Delegated subnet ID for regional VNet integration. Null disables integration."
}

variable "public_network_access_enabled" {
  type        = bool
  default     = true
  description = "Whether the app is reachable over public endpoints. Set false to force Private Endpoint access."
}

# ---------------------------------------------------------------------------
# Inbound allow lists
#
# Both default to an empty list; combined with the module's "Deny" default
# action, an empty list means nothing inbound reaches the app.
# ---------------------------------------------------------------------------
variable "ip_restrictions" {
  description = "Inbound allow rules for the app. Provide either ip_address (CIDR) or service_tag, never both."
  type = list(object({
    name        = string
    priority    = number
    action      = optional(string, "Allow")
    ip_address  = optional(string)
    service_tag = optional(string)
  }))
  default = []
}

variable "scm_ip_restrictions" {
  description = "Inbound allow rules for the SCM (deployment) endpoint. Keep this tighter than the app allow list."
  type = list(object({
    name        = string
    priority    = number
    action      = optional(string, "Allow")
    ip_address  = optional(string)
    service_tag = optional(string)
  }))
  default = []
}

# ---------------------------------------------------------------------------
# Application settings
# ---------------------------------------------------------------------------
variable "app_settings" {
  type        = map(string)
  default     = {}
  description = "Application settings. Do not put the auth secret here; the authentication block manages it."
}

# ---------------------------------------------------------------------------
# Authentication (Entra ID / Azure AD)
#
# Enabled when authentication_enabled is true, in which case client_id,
# client_secret, and tenant_id are required.
# ---------------------------------------------------------------------------
variable "authentication_enabled" {
  type        = bool
  default     = false
  description = "Require Entra ID authentication before the app is reachable."
}

variable "authentication_client_id" {
  type        = string
  default     = null
  description = "Client ID of the app registration."
}

variable "authentication_client_secret" {
  type        = string
  default     = null
  sensitive   = true
  description = "Client secret of the app registration. Stored as the MICROSOFT_PROVIDER_AUTHENTICATION_SECRET app setting."
}

variable "authentication_tenant_id" {
  type        = string
  default     = null
  description = "Entra ID tenant ID used to build the auth endpoint."
}

variable "authentication_allowed_redirect_urls" {
  type        = list(string)
  default     = []
  description = "External redirect URLs permitted after login."
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
variable "enable_detailed_errors" {
  type        = bool
  default     = true
  description = "Return detailed error pages. Useful in production for diagnosis; disable if error detail must not leak."
}

variable "enable_failed_request_tracing" {
  type        = bool
  default     = true
  description = "Trace failed requests. Essential for post-incident diagnosis."
}

variable "application_log_level" {
  type        = string
  default     = "Verbose"
  description = "Application log level: Off, Error, Warning, Information, or Verbose."
}

variable "http_log_retention_days" {
  type        = number
  default     = 14
  description = "HTTP log retention in days."
}

variable "http_log_retention_mb" {
  type        = number
  default     = 35
  description = "HTTP log retention ceiling in megabytes."
}

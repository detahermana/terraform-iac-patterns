# ---------------------------------------------------------------------------
# Naming and placement
# ---------------------------------------------------------------------------
variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to create for the network."
}

variable "location" {
  type        = string
  description = "Azure region, e.g. \"uksouth\"."
}

variable "vnet_name" {
  type        = string
  description = "Name of the virtual network."
}

variable "address_space" {
  type        = list(string)
  description = "Address space for the virtual network, e.g. [\"10.0.0.0/16\"]."
}

variable "dns_servers" {
  type        = list(string)
  default     = []
  description = "Custom DNS servers for the virtual network. Empty uses Azure-provided DNS."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource the module creates."
}

# ---------------------------------------------------------------------------
# Subnets
#
# Keyed map so callers name their own subnets and the module stays generic.
# `delegation` is set only for subnets that back a delegated service
# (App Service VNet integration, Private Endpoints, etc.).
# ---------------------------------------------------------------------------
variable "subnets" {
  description = "Subnets to create, keyed by a stable identifier."
  type = map(object({
    name             = string
    address_prefixes = list(string)
    delegation = optional(object({
      name         = string
      service_name = string
      actions      = list(string)
    }))
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# Network security group and its rules
# ---------------------------------------------------------------------------
variable "create_network_security_group" {
  type        = bool
  default     = true
  description = "Whether to create an NSG and its rules."
}

variable "nsg_name" {
  type        = string
  default     = null
  description = "Name of the network security group. Required when create_network_security_group is true."
}

variable "security_rules" {
  description = "Ordered inbound/outbound rules for the NSG."
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    description                = optional(string)
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
  default = []
}

variable "nsg_subnet_associations" {
  description = "Map of subnet key -> {} to attach the NSG to. Keys must exist in var.subnets."
  type        = map(bool)
  default     = {}
}

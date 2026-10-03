# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------
variable "name" {
  type        = string
  description = "Name of the virtual machine. Also used as the prefix for the NIC and data disk."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to deploy into."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID the NIC attaches to."
}

variable "private_ip_address" {
  type        = string
  default     = null
  description = "Static private IP. Null uses dynamic allocation."
}

variable "dns_servers" {
  type        = list(string)
  default     = []
  description = "DNS servers for the NIC. Empty inherits the virtual network setting."
}

variable "zone" {
  type        = string
  default     = null
  description = "Availability zone, e.g. \"1\". Null lets the platform choose."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource the module creates."
}

# ---------------------------------------------------------------------------
# Size and access
# ---------------------------------------------------------------------------
variable "size" {
  type        = string
  description = "Azure VM size, e.g. \"Standard_D2s_v5\"."
}

variable "admin_username" {
  type        = string
  default     = "azureuser"
  description = "Local administrator username."
}

variable "admin_ssh_public_key" {
  type        = string
  description = "SSH public key for the admin user. Required: the VM has password authentication disabled, so this is the only way in. The private key is never passed to the module."
}

# ---------------------------------------------------------------------------
# Disks
# ---------------------------------------------------------------------------
variable "os_disk" {
  description = "Operating system disk configuration."
  type = object({
    caching              = optional(string, "ReadWrite")
    storage_account_type = optional(string, "Premium_LRS")
    size_gb              = optional(number, 64)
  })
  default = {}
}

variable "data_disk" {
  description = "Optional data disk. Null creates a VM with no data disk."
  type = object({
    storage_account_type = optional(string, "Premium_LRS")
    size_gb              = number
    lun                  = optional(number, 0)
    caching              = optional(string, "ReadOnly")
  })
  default = null
}

# ---------------------------------------------------------------------------
# Image
# ---------------------------------------------------------------------------
variable "image" {
  description = "Marketplace image reference."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = optional(string, "latest")
  })
}

variable "marketplace_plan" {
  description = "Marketplace plan details. Required for images sold through the marketplace (RHEL, SUSE, and similar)."
  type = object({
    name      = string
    product   = string
    publisher = string
  })
  default = null
}

# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------
variable "enable_azure_monitor_agent" {
  type        = bool
  default     = true
  description = "Deploy the Azure Monitor Linux agent extension."
}

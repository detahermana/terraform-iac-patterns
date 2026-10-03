# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------
variable "instance_name" {
  type        = string
  description = "Name of the compute instance."
}

variable "zone" {
  type        = string
  description = "GCP zone, e.g. \"europe-west2-a\"."
}

variable "region" {
  type        = string
  description = "GCP region, e.g. \"europe-west2\". Must match the zone."
}

variable "machine_type" {
  type        = string
  default     = "e2-medium"
  description = "Machine type, e.g. \"e2-medium\"."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to the instance."
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
variable "network_name" {
  type        = string
  description = "Name of the VPC network to create."
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnetwork to create."
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR range for the subnetwork, e.g. \"10.0.1.0/24\"."
}

variable "private_ip_google_access" {
  type        = bool
  default     = true
  description = "Allow instances without a public IP to reach Google APIs."
}

variable "network_tags" {
  type        = list(string)
  default     = []
  description = "Network tags applied to the instance. Firewall rules target these tags."
}

# ---------------------------------------------------------------------------
# Firewall
# ---------------------------------------------------------------------------
variable "firewall_rules" {
  description = "Firewall rules to create, applied by network tag. source_ranges applies to INGRESS, destination_ranges to EGRESS."
  type = list(object({
    name               = string
    direction          = string
    priority           = optional(number, 1000)
    protocol           = string
    ports              = list(string)
    target_tags        = list(string)
    source_ranges      = optional(list(string))
    destination_ranges = optional(list(string))
  }))
  default = []
}

# ---------------------------------------------------------------------------
# Boot disk
# ---------------------------------------------------------------------------
variable "boot_image" {
  type        = string
  default     = "debian-cloud/debian-12"
  description = "Boot image, as a public image path."
}

variable "boot_disk_size_gb" {
  type        = number
  default     = 20
  description = "Boot disk size in gigabytes."
}

variable "boot_disk_type" {
  type        = string
  default     = "pd-balanced"
  description = "Boot disk type: pd-standard, pd-balanced, or pd-ssd."
}

# ---------------------------------------------------------------------------
# Access and identity
# ---------------------------------------------------------------------------
variable "static_public_ip" {
  type        = bool
  default     = false
  description = "Attach a static public IP. When false the instance has no public address."
}

variable "service_account_email" {
  type        = string
  default     = null
  description = "Service account email. Null uses the project default."
}

variable "service_account_scopes" {
  type        = list(string)
  default     = ["cloud-platform"]
  description = "OAuth scopes for the instance service account. Narrow these for least privilege."
}

# ---------------------------------------------------------------------------
# Hardening and lifecycle
# ---------------------------------------------------------------------------
variable "enable_shielded_vm" {
  type        = bool
  default     = true
  description = "Enable Shielded VM (secure boot, vTPM, integrity monitoring)."
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Block Terraform from destroying the instance. Enable for stateful nodes."
}

variable "metadata" {
  type        = map(string)
  default     = {}
  description = "Instance metadata key/value pairs."
}

variable "startup_script" {
  type        = string
  default     = null
  description = "Startup script run on first boot. Null creates the instance without one."
}

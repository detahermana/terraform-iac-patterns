# ---------------------------------------------------------------------------
# Naming
# ---------------------------------------------------------------------------
variable "vpc_name" {
  type        = string
  description = "Name tag applied to the VPC and used as the prefix for subnet and gateway names."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource the module creates."
}

# ---------------------------------------------------------------------------
# Addressing
# ---------------------------------------------------------------------------
variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC. Ignored when vpc_id is set."
}

variable "vpc_id" {
  type        = string
  default     = null
  description = "Existing VPC ID to attach to. Null creates a new VPC from vpc_cidr."
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = []
  description = "CIDR blocks for public subnets. One subnet is created per entry, spread across available AZs."
}

variable "private_subnet_cidrs" {
  type        = list(string)
  default     = []
  description = "CIDR blocks for private subnets. One subnet is created per entry, spread across available AZs."
}

variable "create_internet_gateway" {
  type        = bool
  default     = true
  description = "Create an internet gateway and route public subnets to it. Set false for a fully private VPC."
}

# ---------------------------------------------------------------------------
# Security groups
#
# A map so callers declare named groups with their rules. Egress must be stated
# explicitly: the module does not add a default allow-all rule.
# ---------------------------------------------------------------------------
variable "security_groups" {
  description = "Security groups to create, keyed by group name."
  type = map(object({
    description = string
    ingress = list(object({
      description     = optional(string)
      from_port       = number
      to_port         = number
      protocol        = string
      cidr_blocks     = optional(list(string))
      security_groups = optional(list(string))
    }))
    egress = list(object({
      description = optional(string)
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = optional(list(string))
    }))
  }))
  default = {}
}

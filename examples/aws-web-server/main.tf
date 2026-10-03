# Example: AWS VPC with public/private subnets and scoped security groups
#
# Demonstrates the aws-network module twice, composed at the call site: the
# first call builds the VPC and the load balancer group, the second attaches
# the application group which references the first group by ID.
#
# Why two calls instead of one: a security group that references another group
# inside the same module call creates a dependency cycle (the module's input
# depends on the module's own output). Referencing across two calls expresses
# the dependency without the cycle.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

locals {
  tags = {
    Environment = "production"
    Workload    = "web-tier"
    ManagedBy   = "Terraform"
  }
}

# ---------------------------------------------------------------------------
# Network: VPC, subnets, internet gateway, and the load balancer group
#
# trivy:ignore:AVD-AWS-0164 — a public subnet is the point of this example: the
# load balancer lives in it and needs a public IP. In production, place only
# internet-facing resources here and keep application hosts in the private
# subnets.
# ---------------------------------------------------------------------------
#trivy:ignore:AVD-AWS-0164
module "network" {
  source = "../../modules/aws-network"

  vpc_name = "vpc-web-tier"

  vpc_cidr             = "10.30.0.0/16"
  public_subnet_cidrs  = ["10.30.1.0/24", "10.30.2.0/24"]
  private_subnet_cidrs = ["10.30.11.0/24", "10.30.12.0/24"]

  tags = local.tags

  security_groups = {
    "sg-web-lb" = {
      description = "Public load balancer. HTTPS in, health checks out."

      ingress = [
        {
          description = "HTTPS from anywhere."
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]

      egress = [
        {
          description = "Health checks to the application tier."
          from_port   = 8080
          to_port     = 8080
          protocol    = "tcp"
          cidr_blocks = ["10.30.11.0/24", "10.30.12.0/24"]
        }
      ]
    }
  }
}

# ---------------------------------------------------------------------------
# Application security group
#
# References the load balancer group from the first call. That reference is why
# this is a second module call rather than another entry in the map above.
#
# trivy:ignore:AVD-AWS-0104 — the application tier needs unrestricted egress on
# 443 for package updates and third-party API calls. Egress to a fixed set of
# addresses is not practical for a general-purpose web tier; if your workload
# only talks to known endpoints, scope this down instead.
# ---------------------------------------------------------------------------
#trivy:ignore:AVD-AWS-0104
module "app_security" {
  source = "../../modules/aws-network"

  # Attach to the VPC created by the first call instead of making a new one.
  vpc_id = module.network.vpc_id

  # No subnets or gateway: this call only contributes a security group. The
  # provider still needs a name for the module's name-prefix logic.
  vpc_name                = "vpc-web-tier"
  create_internet_gateway = false

  tags = local.tags

  security_groups = {
    "sg-app" = {
      description = "Application tier. Reachable only from the load balancer."

      ingress = [
        {
          description     = "Traffic from the web load balancer only."
          from_port       = 8080
          to_port         = 8080
          protocol        = "tcp"
          security_groups = [module.network.security_group_ids["sg-web-lb"]]
        }
      ]

      egress = [
        {
          description = "Updates and API calls."
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]
    }
  }
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "security_group_ids" {
  value = merge(module.network.security_group_ids, module.app_security.security_group_ids)
}

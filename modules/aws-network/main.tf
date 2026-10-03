terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Availability zones
#
# Resolved from the region rather than hard-coded, so the same module works in
# any region the caller targets.
# ---------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------------------
# VPC
#
# Two modes, chosen by var.vpc_id:
#   - vpc_id null  -> create a new VPC from var.vpc_cidr
#   - vpc_id set   -> attach to an existing VPC (used to add subnets or
#                     security groups to a VPC that already exists)
# This is what lets a second module call contribute security groups to a VPC
# the first call created, without a dependency cycle.
# ---------------------------------------------------------------------------
resource "aws_vpc" "this" {
  count = var.vpc_id == null ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = var.vpc_name })
}

locals {
  vpc_id = coalesce(var.vpc_id, try(aws_vpc.this[0].id, null))
}

# ---------------------------------------------------------------------------
# Subnets
#
# `public` subnets get a route to the internet gateway; `private` subnets do
# not, so instances in them reach the internet only through a NAT gateway
# (created by the caller or a later iteration) or not at all.
# ---------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = local.vpc_id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = local.vpc_id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-private-${count.index + 1}"
    Tier = "private"
  })
}

# ---------------------------------------------------------------------------
# Internet gateway and routing
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  count = var.create_internet_gateway ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(var.tags, { Name = "${var.vpc_name}-igw" })
}

resource "aws_route_table" "public" {
  count = var.create_internet_gateway ? 1 : 0

  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge(var.tags, { Name = "${var.vpc_name}-public" })
}

resource "aws_route_table_association" "public" {
  count = var.create_internet_gateway ? length(aws_subnet.public) : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# ---------------------------------------------------------------------------
# Security groups
#
# Each group is declared once with its rules inline. Ingress and egress are
# explicit: the default allow-all egress is replaced so outbound traffic is a
# deliberate decision, not an accident.
# ---------------------------------------------------------------------------
resource "aws_security_group" "this" {
  for_each = var.security_groups

  name        = each.key
  description = each.value.description
  vpc_id      = local.vpc_id

  dynamic "ingress" {
    for_each = each.value.ingress

    content {
      description     = try(ingress.value.description, null)
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      cidr_blocks     = try(ingress.value.cidr_blocks, [])
      security_groups = try(ingress.value.security_groups, [])
    }
  }

  dynamic "egress" {
    for_each = each.value.egress

    content {
      description = try(egress.value.description, null)
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = try(egress.value.cidr_blocks, [])
    }
  }

  tags = merge(var.tags, { Name = each.key })

  lifecycle {
    create_before_destroy = true
  }
}

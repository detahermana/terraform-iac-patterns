terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Resource group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Virtual network
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.address_space
  dns_servers         = var.dns_servers
  tags                = var.tags

  lifecycle {
    ignore_changes = [
      tags["LastBackup"],
    ]
  }
}

# ---------------------------------------------------------------------------
# Subnets
#
# `delegation` is optional per subnet and is what lets an App Service do
# VNet integration or a Private Endpoint bind to the subnet.
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value.address_prefixes

  dynamic "delegation" {
    for_each = each.value.delegation == null ? [] : [each.value.delegation]

    content {
      name = delegation.value.name

      service_delegation {
        name    = delegation.value.service_name
        actions = delegation.value.actions
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Network security group
#
# Rules are declared as an ordered list of objects rather than one resource
# block per rule. This keeps the call site compact and makes the rule set
# reviewable at a glance — the same shape a security review expects.
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "this" {
  count = var.create_network_security_group ? 1 : 0

  name                = var.nsg_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "this" {
  for_each = var.create_network_security_group ? { for r in var.security_rules : r.name => r } : {}

  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  description                 = try(each.value.description, null)
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this[0].name
}

# ---------------------------------------------------------------------------
# Optional NSG -> subnet association
# Without this, the NSG exists but enforces nothing.
# ---------------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = var.nsg_subnet_associations

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[0].id
}

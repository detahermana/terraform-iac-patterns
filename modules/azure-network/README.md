# azure-network

Creates an Azure resource group, a virtual network, subnets (with optional
service delegation), a network security group with an ordered rule set, and the
NSG-to-subnet associations.

## What it creates

| Resource | Notes |
|---|---|
| `azurerm_resource_group` | Owns everything else the module creates |
| `azurerm_virtual_network` | Address space and optional custom DNS |
| `azurerm_subnet` | One per entry in `var.subnets`; optional delegation |
| `azurerm_network_security_group` | Optional |
| `azurerm_network_security_rule` | One per entry in `var.security_rules` |
| `azurerm_subnet_network_security_group_association` | Opt-in per subnet |

## Why subnets carry their own delegation

A subnet that an App Service integrates with, or that a Private Endpoint binds
to, must be delegated to the consuming service. Modelling delegation as part of
the subnet object keeps that requirement next to the address prefix it applies
to, instead of in a separate resource block that is easy to forget.

Without the delegation, App Service VNet integration fails at apply time with a
message about the subnet not being delegated to `Microsoft.Web/serverFarms`.

## Why rules are a list, not one block each

`var.security_rules` is an ordered list of objects. A security review reads a
rule set top to bottom by priority; a Terraform file with twenty separate
`resource` blocks does not read that way. The list also makes it obvious when
no rules exist.

## Usage

```hcl
module "network" {
  source = "../../modules/azure-network"

  resource_group_name = "rg-uks-p-app"
  location            = "uksouth"
  vnet_name           = "vnet-uks-p-app"
  address_space       = ["10.20.0.0/16"]
  tags                = local.tags

  subnets = {
    app = {
      name             = "snet-uks-p-app"
      address_prefixes = ["10.20.1.0/24"]
      delegation = {
        name         = "app-service-delegation"
        service_name = "Microsoft.Web/serverFarms"
        actions      = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    }
  }

  nsg_name = "nsg-uks-p-app"

  security_rules = [
    {
      name                       = "Allow-HTTPS-Inbound"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "AzureFrontDoor.Backend"
      destination_address_prefix = "10.20.1.0/24"
    }
  ]

  nsg_subnet_associations = { app = true }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `resource_group_name` | `string` | — | Resource group to create |
| `location` | `string` | — | Azure region |
| `vnet_name` | `string` | — | Virtual network name |
| `address_space` | `list(string)` | — | VNet address space |
| `dns_servers` | `list(string)` | `[]` | Custom DNS servers |
| `tags` | `map(string)` | `{}` | Tags for all resources |
| `subnets` | `map(object)` | `{}` | Subnets keyed by identifier |
| `create_network_security_group` | `bool` | `true` | Create the NSG |
| `nsg_name` | `string` | `null` | NSG name |
| `security_rules` | `list(object)` | `[]` | NSG rules |
| `nsg_subnet_associations` | `map(bool)` | `{}` | Subnet keys to associate |

## Outputs

| Name | Description |
|---|---|
| `resource_group_name` | Created resource group name |
| `resource_group_id` | Created resource group ID |
| `vnet_id` | Virtual network ID |
| `vnet_name` | Virtual network name |
| `subnet_ids` | Map of subnet key to subnet ID |
| `network_security_group_id` | NSG ID, or `null` |

## Note

Delegation is opt-in and unset by default — a subnet with no delegation
behaves as an ordinary subnet.

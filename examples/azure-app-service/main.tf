# Example: Azure App Service behind Front Door, into a delegated subnet
#
# Wires the network module and the app-service module together, which is the
# part that is easy to get wrong by hand: the subnet must exist and be
# delegated to Microsoft.Web before the app can integrate with it.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  environment  = "p"
  region       = "uksouth"
  region_short = "uks"
  workload     = "webapp"

  tags = {
    Environment = local.environment
    Workload    = local.workload
    ManagedBy   = "Terraform"
  }
}

# ---------------------------------------------------------------------------
# Network: VNet, a delegated subnet for the app, and a subnet for endpoints
# ---------------------------------------------------------------------------
module "network" {
  source = "../../modules/azure-network"

  resource_group_name = "rg-${local.region_short}-${local.environment}-${local.workload}"
  location            = local.region
  vnet_name           = "vnet-${local.region_short}-${local.environment}-${local.workload}"
  address_space       = ["10.20.0.0/16"]
  tags                = local.tags

  subnets = {
    app = {
      name             = "snet-${local.region_short}-${local.environment}-app"
      address_prefixes = ["10.20.1.0/24"]

      # This delegation is what makes App Service VNet integration possible.
      delegation = {
        name         = "app-service-delegation"
        service_name = "Microsoft.Web/serverFarms"
        actions      = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    }

    endpoints = {
      name             = "snet-${local.region_short}-${local.environment}-endpoints"
      address_prefixes = ["10.20.2.0/24"]
    }
  }

  nsg_name = "nsg-${local.region_short}-${local.environment}-${local.workload}"

  security_rules = [
    {
      name                       = "Allow-HTTPS-Inbound"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      description                = "HTTPS from the Front Door service tag only."
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "AzureFrontDoor.Backend"
      destination_address_prefix = "10.20.1.0/24"
    }
  ]

  nsg_subnet_associations = {
    app = true
  }
}

# ---------------------------------------------------------------------------
# App Service: plan + web app, VNet-integrated, locked to Front Door, Entra ID
# ---------------------------------------------------------------------------
module "app" {
  source = "../../modules/azure-app-service"

  app_name            = "as-${local.region_short}-${local.environment}-${local.workload}"
  plan_name           = "asp-${local.region_short}-${local.environment}-${local.workload}"
  location            = local.region
  resource_group_name = module.network.resource_group_name
  tags                = local.tags

  sku_name     = "P1v3"
  node_version = "20-lts"

  vnet_integration_subnet_id = module.network.subnet_ids["app"]

  # Nothing reaches the app except Front Door. Front Door is the only entry
  # point, which is also where WAF would sit in a larger deployment.
  ip_restrictions = [
    {
      name        = "AllowFrontDoor"
      priority    = 100
      service_tag = "AzureFrontDoor.Backend"
    }
  ]

  # SCM (deployment) endpoint is reachable only from the operations network.
  scm_ip_restrictions = [
    {
      name       = "AllowOperationsNetwork"
      priority   = 100
      ip_address = "203.0.113.0/24"
    }
  ]

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }

  # Uncomment to require Entra ID login. Needs an app registration.
  #
  # authentication_enabled              = true
  # authentication_client_id            = var.auth_client_id
  # authentication_client_secret        = var.auth_client_secret
  # authentication_tenant_id            = var.auth_tenant_id
  # authentication_allowed_redirect_urls = ["https://app.example.org"]
}

output "app_hostname" {
  value = module.app.default_hostname
}

output "app_principal_id" {
  value = module.app.principal_id
}

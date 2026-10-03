# azure-app-service

Creates an App Service plan and a Windows web app with a hardened default
posture: HTTPS only, VNet integration, deny-by-default inbound restrictions,
and optional Entra ID authentication.

## What it creates

| Resource | Notes |
|---|---|
| `azurerm_service_plan` | Windows or Linux, caller-chosen SKU |
| `azurerm_windows_web_app` | HTTPS-only, VNet-integrated, IP-restricted |

## Security posture

The module makes the secure choice the default:

- **HTTPS only.** `https_only = true`. There is no switch to disable it.
- **Deny by default.** `ip_restriction_default_action` and the SCM equivalent
  are `Deny`. An empty allow list means nothing inbound reaches the app.
- **Separate SCM allow list.** The deployment (SCM) endpoint is restricted
  independently of the app, so a deployment path can be narrower than the
  application path.
- **VNet integration.** Passing a delegated subnet binds outbound traffic to
  the network rather than the public internet.
- **Optional Entra ID.** When enabled, unauthenticated requests are redirected
  to login before the application code runs.

## The delegation dependency

`var.vnet_integration_subnet_id` must be a subnet delegated to
`Microsoft.Web/serverFarms`. The network module handles that; if the subnet was
created by hand, apply fails with a delegation error.

## The auth secret

When `authentication_enabled` is true, the module sets the app setting
`MICROSOFT_PROVIDER_AUTHENTICATION_SECRET` from
`var.authentication_client_secret`, and the auth block references that setting
**by name**. The secret is therefore stored once and never duplicated across
two places in the configuration.

## Usage

```hcl
module "web_app" {
  source = "../../modules/azure-app-service"

  app_name            = "as-uks-p-portal"
  plan_name           = "asp-uks-p-portal"
  location            = "uksouth"
  resource_group_name = module.network.resource_group_name
  tags                = local.tags

  sku_name                   = "P1v3"
  vnet_integration_subnet_id = module.network.subnet_ids["app"]

  ip_restrictions = [
    {
      name        = "AllowFrontDoor"
      priority    = 100
      service_tag = "AzureFrontDoor.Backend"
    }
  ]

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `app_name` | `string` | — | Web app name (lowercased) |
| `plan_name` | `string` | — | App Service plan name |
| `location` | `string` | — | Azure region |
| `resource_group_name` | `string` | — | Resource group |
| `os_type` | `string` | `Windows` | Plan OS |
| `sku_name` | `string` | `P1v3` | Plan SKU |
| `node_version` | `string` | `20-lts` | Runtime version |
| `minimum_tls_version` | `string` | `1.2` | Minimum inbound TLS |
| `vnet_integration_subnet_id` | `string` | `null` | Delegated subnet |
| `public_network_access_enabled` | `bool` | `true` | Public endpoint access |
| `ip_restrictions` | `list(object)` | `[]` | App inbound allow rules |
| `scm_ip_restrictions` | `list(object)` | `[]` | SCM inbound allow rules |
| `app_settings` | `map(string)` | `{}` | Application settings |
| `authentication_enabled` | `bool` | `false` | Require Entra ID |
| `authentication_client_id` | `string` | `null` | App registration client ID |
| `authentication_client_secret` | `string` | `null` | App registration secret (sensitive) |
| `authentication_tenant_id` | `string` | `null` | Entra ID tenant ID |
| `authentication_allowed_redirect_urls` | `list(string)` | `[]` | Post-login redirect URLs |
| `enable_detailed_errors` | `bool` | `true` | Detailed error pages |
| `enable_failed_request_tracing` | `bool` | `true` | Trace failed requests |
| `application_log_level` | `string` | `Verbose` | App log level |
| `http_log_retention_days` | `number` | `14` | HTTP log retention |
| `http_log_retention_mb` | `number` | `35` | HTTP log size cap |
| `tags` | `map(string)` | `{}` | Tags for all resources |

## Outputs

| Name | Description |
|---|---|
| `app_id` | Web app ID |
| `app_name` | Web app name |
| `default_hostname` | Default hostname |
| `service_plan_id` | Plan ID |
| `principal_id` | Managed identity principal ID, or `null` |

## Note

Windows and Linux plans are not interchangeable. Switching `os_type` on an
existing plan forces replacement of the plan and everything on it. Settle the
OS before the first apply.

The module creates `azurerm_windows_web_app`. For Linux plans, swap the
resource type to `azurerm_linux_web_app` — the rest of the configuration is
identical apart from `application_stack`.

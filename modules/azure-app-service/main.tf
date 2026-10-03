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
# App Service plan
# ---------------------------------------------------------------------------
resource "azurerm_service_plan" "this" {
  name                = var.plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = var.os_type
  sku_name            = var.sku_name
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Web app
#
# Security posture baked into the module:
#   - HTTPS only
#   - VNet integration through a delegated subnet (no public egress by default)
#   - inbound IP restrictions default to Deny, with an explicit allow list
#   - optional Entra ID authentication required before the app is reachable
# ---------------------------------------------------------------------------
resource "azurerm_windows_web_app" "this" {
  name                          = lower(var.app_name)
  location                      = var.location
  resource_group_name           = var.resource_group_name
  service_plan_id               = azurerm_service_plan.this.id
  https_only                    = true
  virtual_network_subnet_id     = var.vnet_integration_subnet_id
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags

  depends_on = [azurerm_service_plan.this]

  site_config {
    use_32_bit_worker = false

    application_stack {
      node_version = var.node_version
    }

    # Deny by default, then allow exactly what is listed. An empty allow list
    # means nothing inbound reaches the app except through the platform.
    ip_restriction_default_action     = "Deny"
    scm_ip_restriction_default_action = "Deny"

    dynamic "ip_restriction" {
      for_each = var.ip_restrictions

      content {
        name        = ip_restriction.value.name
        priority    = ip_restriction.value.priority
        action      = ip_restriction.value.action
        ip_address  = try(ip_restriction.value.ip_address, null)
        service_tag = try(ip_restriction.value.service_tag, null)
      }
    }

    dynamic "scm_ip_restriction" {
      for_each = var.scm_ip_restrictions

      content {
        name        = scm_ip_restriction.value.name
        priority    = scm_ip_restriction.value.priority
        action      = scm_ip_restriction.value.action
        ip_address  = try(scm_ip_restriction.value.ip_address, null)
        service_tag = try(scm_ip_restriction.value.service_tag, null)
      }
    }
  }

  # Callers pass app settings as a map. The TLS floor is always set. When
  # authentication is enabled, the app-registration secret is injected here so
  # it is referenced by name from the auth block below and never duplicated.
  app_settings = merge(
    { minTlsVersion = var.minimum_tls_version },
    var.app_settings,
    var.authentication_enabled ? {
      MICROSOFT_PROVIDER_AUTHENTICATION_SECRET = var.authentication_client_secret
    } : {}
  )

  # Entra ID (Azure AD) authentication. Enabled only when a client ID and
  # secret are supplied, so the module works for both public and gated apps.
  dynamic "auth_settings_v2" {
    for_each = var.authentication_enabled ? [1] : []

    content {
      auth_enabled             = true
      runtime_version          = "~2"
      require_authentication   = true
      unauthenticated_action   = "RedirectToLoginPage"
      default_provider         = "azureactivedirectory"
      forward_proxy_convention = "Standard"

      login {
        token_store_enabled            = true
        allowed_external_redirect_urls = var.authentication_allowed_redirect_urls
      }

      active_directory_v2 {
        client_id                  = var.authentication_client_id
        client_secret_setting_name = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
        tenant_auth_endpoint       = "https://sts.windows.net/${var.authentication_tenant_id}/v2.0"
        allowed_applications       = [var.authentication_client_id]
      }
    }
  }

  # Request tracing and log retention. `failed_request_tracing` in particular
  # is what makes a production incident diagnosable after the fact.
  logs {
    detailed_error_messages = var.enable_detailed_errors
    failed_request_tracing  = var.enable_failed_request_tracing

    application_logs {
      file_system_level = var.application_log_level
    }

    http_logs {
      file_system {
        retention_in_days = var.http_log_retention_days
        retention_in_mb   = var.http_log_retention_mb
      }
    }
  }

  lifecycle {
    ignore_changes = [
      tags["LastBackup"],
    ]
  }
}

output "app_id" {
  description = "ID of the web app."
  value       = azurerm_windows_web_app.this.id
}

output "app_name" {
  description = "Name of the web app."
  value       = azurerm_windows_web_app.this.name
}

output "default_hostname" {
  description = "Default hostname of the web app."
  value       = azurerm_windows_web_app.this.default_hostname
}

output "service_plan_id" {
  description = "ID of the App Service plan."
  value       = azurerm_service_plan.this.id
}

output "principal_id" {
  description = "Principal (managed identity) ID of the web app, when a system-assigned identity is enabled."
  value       = try(azurerm_windows_web_app.this.identity[0].principal_id, null)
}

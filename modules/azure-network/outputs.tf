output "resource_group_name" {
  description = "Name of the created resource group."
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "ID of the created resource group."
  value       = azurerm_resource_group.this.id
}

output "vnet_id" {
  description = "ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "Map of subnet key -> subnet ID. Consumers pass these to VMs, App Services, or Private Endpoints."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}

output "network_security_group_id" {
  description = "ID of the NSG, or null when none was created."
  value       = var.create_network_security_group ? azurerm_network_security_group.this[0].id : null
}

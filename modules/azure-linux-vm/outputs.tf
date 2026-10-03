output "vm_id" {
  description = "ID of the virtual machine."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "Name of the virtual machine."
  value       = azurerm_linux_virtual_machine.this.name
}

output "private_ip_address" {
  description = "Private IP address assigned to the NIC."
  value       = azurerm_network_interface.this.private_ip_address
}

output "network_interface_id" {
  description = "ID of the network interface."
  value       = azurerm_network_interface.this.id
}

output "data_disk_id" {
  description = "ID of the data disk, or null when none was created."
  value       = var.data_disk == null ? null : azurerm_managed_disk.data[0].id
}

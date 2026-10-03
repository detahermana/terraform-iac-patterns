terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Admin password
#
# Generated locally so it never has to be passed in as a variable, and never
# lands in the call site. Retrieve it with `terraform output -raw admin_password`
# when the apply is done, then move it into a secrets store.
# ---------------------------------------------------------------------------
resource "random_password" "admin" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

# ---------------------------------------------------------------------------
# Network interface
#
# The NIC carries the private IP and the subnet binding; the VM references it.
# Splitting these is what lets the NIC (and therefore the IP) survive a VM
# rebuild without losing addressing.
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "this" {
  name                = "${var.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_servers         = var.dns_servers
  tags                = var.tags

  ip_configuration {
    name                          = "${var.name}-ipconfig"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip_address == null ? "Dynamic" : "Static"
    private_ip_address            = var.private_ip_address
  }
}

# ---------------------------------------------------------------------------
# Virtual machine
# ---------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "this" {
  name                            = var.name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.size
  zone                            = var.zone
  admin_username                  = var.admin_username
  admin_password                  = random_password.admin.result
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.this.id]
  tags                            = var.tags

  boot_diagnostics {}

  os_disk {
    caching              = var.os_disk.caching
    storage_account_type = var.os_disk.storage_account_type
    disk_size_gb         = var.os_disk.size_gb
  }

  # Marketplace image. `plan` is required only for images sold via the
  # marketplace (RHEL, SUSE, some security appliances).
  dynamic "plan" {
    for_each = var.marketplace_plan == null ? [] : [var.marketplace_plan]

    content {
      name      = plan.value.name
      product   = plan.value.product
      publisher = plan.value.publisher
    }
  }

  source_image_reference {
    publisher = var.image.publisher
    offer     = var.image.offer
    sku       = var.image.sku
    version   = var.image.version
  }

  # Fields managed outside Terraform (image patching, backup tagging,
  # platform-side NIC attachment) are ignored so a routine apply does not
  # try to revert them.
  lifecycle {
    ignore_changes = [
      tags["LastBackup"],
      network_interface_ids,
      identity,
      source_image_reference,
    ]
  }
}

# ---------------------------------------------------------------------------
# Data disk
# ---------------------------------------------------------------------------
resource "azurerm_managed_disk" "data" {
  count = var.data_disk == null ? 0 : 1

  name                 = "${var.name}-data"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = var.data_disk.storage_account_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk.size_gb
  zone                 = var.zone
  tags                 = var.tags

  lifecycle {
    ignore_changes = [
      create_option,
      storage_account_id,
      source_resource_id,
    ]
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  count = var.data_disk == null ? 0 : 1

  managed_disk_id    = azurerm_managed_disk.data[0].id
  virtual_machine_id = azurerm_linux_virtual_machine.this.id
  lun                = var.data_disk.lun
  caching            = var.data_disk.caching
}

# ---------------------------------------------------------------------------
# Azure Monitor agent
#
# Deployed by default: an unmonitored VM is a blind spot, and the extension is
# what feeds the platform's metrics and log pipeline.
# ---------------------------------------------------------------------------
resource "azurerm_virtual_machine_extension" "azure_monitor" {
  count = var.enable_azure_monitor_agent ? 1 : 0

  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.this.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  tags                       = var.tags
}

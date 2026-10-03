# azure-linux-vm

Creates a Linux virtual machine with a network interface, an optional data
disk, and the Azure Monitor agent — plus a generated admin password.

## What it creates

| Resource | Notes |
|---|---|
| `random_password` | 20 characters, mixed class, generated locally |
| `azurerm_network_interface` | Static or dynamic private IP, bound to a subnet |
| `azurerm_linux_virtual_machine` | Optional availability zone, marketplace plan |
| `azurerm_managed_disk` | Optional; created only when `var.data_disk` is set |
| `azurerm_virtual_machine_data_disk_attachment` | Attaches the data disk |
| `azurerm_virtual_machine_extension` | Azure Monitor Linux agent, on by default |

## Why the NIC is separate from the VM

The network interface is its own resource. Splitting them means the interface —
and therefore the private IP address — can survive a VM rebuild, and it makes
the addressing explicit in the plan instead of implicit in the VM block.

## Why the password is generated, not a variable

A password passed in as a variable ends up in a `.tfvars` file, in shell
history, and in CI logs. Generating it inside the module keeps it out of the
call site. Read it once after apply and move it to a secrets store:

```bash
terraform output -raw admin_password
```

## Why `ignore_changes` on those fields

The `lifecycle.ignore_changes` block covers the fields that are legitimately
managed outside Terraform on a running estate:

- `tags["LastBackup"]` — set by the backup system
- `network_interface_ids` — can be modified by platform operations
- `identity` — managed identity can be granted out of band
- `source_image_reference` — patching moves the image version forward

Without this, an unrelated apply would try to revert all four.

## Usage

```hcl
module "app_vm" {
  source = "../../modules/azure-linux-vm"

  name                = "vm-uks-p-app01"
  location            = "uksouth"
  resource_group_name = module.network.resource_group_name
  subnet_id           = module.network.subnet_ids["app"]
  size                = "Standard_D2s_v5"
  zone                = "1"
  tags                = local.tags

  image = {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "8-lvm-gen2"
    version   = "latest"
  }

  marketplace_plan = {
    name      = "8-lvm-gen2"
    product   = "RHEL"
    publisher = "RedHat"
  }

  os_disk = {
    size_gb              = 64
    storage_account_type = "Premium_LRS"
    caching              = "ReadWrite"
  }

  data_disk = {
    size_gb              = 128
    storage_account_type = "Premium_LRS"
    lun                  = 0
    caching              = "ReadOnly"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | — | VM name, also prefixes NIC and data disk |
| `location` | `string` | — | Azure region |
| `resource_group_name` | `string` | — | Resource group |
| `subnet_id` | `string` | — | Subnet for the NIC |
| `size` | `string` | — | VM size |
| `image` | `object` | — | Marketplace image reference |
| `admin_username` | `string` | `azureuser` | Local admin username |
| `private_ip_address` | `string` | `null` | Static IP; null is dynamic |
| `dns_servers` | `list(string)` | `[]` | NIC DNS servers |
| `zone` | `string` | `null` | Availability zone |
| `os_disk` | `object` | see module | OS disk settings |
| `data_disk` | `object` | `null` | Optional data disk |
| `marketplace_plan` | `object` | `null` | Required for marketplace images |
| `enable_azure_monitor_agent` | `bool` | `true` | Deploy the monitoring extension |
| `tags` | `map(string)` | `{}` | Tags for all resources |

## Outputs

| Name | Description |
|---|---|
| `vm_id` | Virtual machine ID |
| `vm_name` | Virtual machine name |
| `private_ip_address` | NIC private IP |
| `network_interface_id` | NIC ID |
| `data_disk_id` | Data disk ID, or `null` |
| `admin_password` | Generated password (sensitive) |

## Note

`admin_password` is a sensitive output. It is still written to state — treat
the state file as a secret, and use a remote backend with encryption and
locking. See the repository README for the backend note.

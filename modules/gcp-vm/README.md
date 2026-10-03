# gcp-vm

Creates a GCP VPC network, a subnetwork, tag-scoped firewall rules, and a
compute instance — private by default, with Shielded VM enabled.

## What it creates

| Resource | Notes |
|---|---|
| `google_compute_network` | Custom subnet mode, regional routing |
| `google_compute_subnetwork` | Single subnet with optional Private Google Access |
| `google_compute_firewall` | One per entry in `var.firewall_rules` |
| `google_compute_address` | Static IP, only when requested |
| `google_compute_instance` | Shielded VM, optional startup script |

## Why firewall rules are tag-scoped

GCP firewall rules are network-scoped and apply to instances by target tag,
unlike AWS security groups or Azure NSGs. Modelling the rules and the instance
tags together in one module keeps the two halves of that contract from drifting
apart — a rule that targets a tag no instance carries is silently dead.

## Why the instance is private by default

`static_public_ip` defaults to `false`. A compute instance with no public
address is reachable only from inside the network, or through IAP or a bastion.
Public exposure then becomes a deliberate choice at the call site, not a
default that has to be remembered and removed.

The example uses the IAP TCP forwarding range (`35.235.240.0/20`) for SSH
rather than `0.0.0.0/0`.

## Usage

```hcl
module "vm" {
  source = "../../modules/gcp-vm"

  instance_name = "vm-app-01"
  zone          = "europe-west2-a"
  region        = "europe-west2"
  machine_type  = "e2-medium"

  network_name = "vpc-app"
  subnet_name  = "snet-app"
  subnet_cidr  = "10.40.1.0/24"

  static_public_ip = false
  network_tags     = ["app", "allow-iap-ssh"]

  firewall_rules = [
    {
      name          = "allow-iap-ssh"
      direction     = "INGRESS"
      protocol      = "tcp"
      ports         = ["22"]
      source_ranges = ["35.235.240.0/20"]
      target_tags   = ["allow-iap-ssh"]
    }
  ]

  boot_image         = "debian-cloud/debian-12"
  boot_disk_size_gb  = 30

  enable_shielded_vm  = true
  deletion_protection = true

  metadata = {
    enable-oslogin = "TRUE"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `instance_name` | `string` | — | Compute instance name |
| `zone` | `string` | — | GCP zone |
| `region` | `string` | — | GCP region |
| `machine_type` | `string` | `e2-medium` | Machine type |
| `network_name` | `string` | — | VPC name |
| `subnet_name` | `string` | — | Subnet name |
| `subnet_cidr` | `string` | — | Subnet CIDR |
| `private_ip_google_access` | `bool` | `true` | Reach Google APIs privately |
| `network_tags` | `list(string)` | `[]` | Instance network tags |
| `firewall_rules` | `list(object)` | `[]` | Firewall rules |
| `boot_image` | `string` | `debian-cloud/debian-12` | Boot image |
| `boot_disk_size_gb` | `number` | `20` | Boot disk size |
| `boot_disk_type` | `string` | `pd-balanced` | Boot disk type |
| `static_public_ip` | `bool` | `false` | Attach a static public IP |
| `service_account_email` | `string` | `null` | Service account |
| `service_account_scopes` | `list(string)` | `["cloud-platform"]` | OAuth scopes |
| `enable_shielded_vm` | `bool` | `true` | Shielded VM |
| `deletion_protection` | `bool` | `false` | Block destroy |
| `metadata` | `map(string)` | `{}` | Instance metadata |
| `startup_script` | `string` | `null` | Startup script |
| `labels` | `map(string)` | `{}` | Instance labels |

## Outputs

| Name | Description |
|---|---|
| `instance_id` | Instance ID |
| `instance_name` | Instance name |
| `internal_ip` | Internal IP |
| `external_ip` | External IP, or `null` |
| `network_id` | VPC network ID |
| `subnet_id` | Subnetwork ID |

## Notes

- `cloud-platform` scope is broad. Narrow `service_account_scopes` when the
  instance only needs specific APIs.
- `deletion_protection` defaults to `false` so examples can be destroyed. Set it
  to `true` for any stateful instance.
- The `region` and `zone` must agree — a subnet is regional, an instance is
  zonal, and a mismatch fails at apply.

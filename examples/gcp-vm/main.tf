# Example: GCP private compute instance with tag-scoped firewall rules
#
# Demonstrates the gcp-vm module: a private VM (no public IP) in its own VPC,
# reachable only through an Identity-Aware Proxy range, with Shielded VM on.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30.0"
    }
  }
}

provider "google" {
  project = "example-project"
  region  = "europe-west2"
}

module "vm" {
  source = "../../modules/gcp-vm"

  instance_name = "vm-app-01"
  zone          = "europe-west2-a"
  region        = "europe-west2"
  machine_type  = "e2-medium"

  labels = {
    environment = "production"
    workload    = "app"
    managed_by  = "terraform"
  }

  network_name = "vpc-app"
  subnet_name  = "snet-app"
  subnet_cidr  = "10.40.1.0/24"

  # No public IP. Operated through IAP or a bastion.
  static_public_ip = false
  network_tags     = ["app", "allow-iap-ssh"]

  firewall_rules = [
    {
      name      = "allow-iap-ssh"
      direction = "INGRESS"
      protocol  = "tcp"
      ports     = ["22"]
      # The IAP TCP forwarding range, not 0.0.0.0/0.
      source_ranges = ["35.235.240.0/20"]
      target_tags   = ["allow-iap-ssh"]
    },
    {
      name          = "allow-internal"
      direction     = "INGRESS"
      protocol      = "tcp"
      ports         = ["0-65535"]
      source_ranges = ["10.40.0.0/16"]
      target_tags   = ["app"]
    }
  ]

  boot_image        = "debian-cloud/debian-12"
  boot_disk_size_gb = 30
  boot_disk_type    = "pd-balanced"

  enable_shielded_vm  = true
  deletion_protection = true

  metadata = {
    enable-oslogin = "TRUE"
  }

  startup_script = <<-EOT
    #!/bin/bash
    set -euo pipefail
    apt-get update
    apt-get install -y unattended-upgrades
    systemctl enable --now unattended-upgrades
  EOT
}

output "internal_ip" {
  value = module.vm.internal_ip
}

output "instance_name" {
  value = module.vm.instance_name
}

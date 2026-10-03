terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Network
#
# GCP firewall rules are network-scoped with target tags, not subnet-scoped
# security groups. The module creates the network, the subnet, and the rules
# together so the tag wiring stays consistent.
# ---------------------------------------------------------------------------
resource "google_compute_network" "this" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  name          = var.subnet_name
  network       = google_compute_network.this.id
  region        = var.region
  ip_cidr_range = var.subnet_cidr

  # Private Google Access lets instances reach Google APIs without a public IP,
  # which is the usual posture for a private compute node.
  private_ip_google_access = var.private_ip_google_access
}

# ---------------------------------------------------------------------------
# Firewall rules
#
# Rules are declared as a list of objects. Applying all of them to one target
# tag keeps the call site readable and the rule set auditable in one place.
# ---------------------------------------------------------------------------
resource "google_compute_firewall" "this" {
  for_each = { for r in var.firewall_rules : r.name => r }

  name      = each.value.name
  network   = google_compute_network.this.id
  direction = each.value.direction
  priority  = each.value.priority

  source_ranges      = each.value.direction == "INGRESS" ? each.value.source_ranges : null
  destination_ranges = each.value.direction == "EGRESS" ? each.value.destination_ranges : null

  allow {
    protocol = each.value.protocol
    ports    = each.value.ports
  }

  target_tags = each.value.target_tags
}

# ---------------------------------------------------------------------------
# Compute instance
# ---------------------------------------------------------------------------
resource "google_compute_address" "this" {
  count = var.static_public_ip ? 1 : 0

  name   = "${var.instance_name}-ip"
  region = var.region
}

resource "google_compute_instance" "this" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.network_tags

  labels = var.labels

  # Instances are not deletable-by-default in Terraform; set true only for
  # stateless nodes. Stateful nodes should be protected.
  deletion_protection = var.deletion_protection

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = var.boot_disk_size_gb
      type  = var.boot_disk_type
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.this.id

    # A public IP is granted only when explicitly requested, and is static in
    # that case. Otherwise the instance is private.
    dynamic "access_config" {
      for_each = var.static_public_ip ? [1] : []

      content {
        nat_ip = google_compute_address.this[0].address
      }
    }
  }

  metadata = var.metadata

  # The startup script is rendered by the caller; the module only ships it.
  metadata_startup_script = var.startup_script

  service_account {
    email  = var.service_account_email
    scopes = var.service_account_scopes
  }

  dynamic "shielded_instance_config" {
    for_each = var.enable_shielded_vm ? [1] : []

    content {
      enable_secure_boot          = true
      enable_vtpm                 = true
      enable_integrity_monitoring = true
    }
  }

  allow_stopping_for_update = true
}

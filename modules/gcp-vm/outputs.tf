output "instance_id" {
  description = "ID of the compute instance."
  value       = google_compute_instance.this.id
}

output "instance_name" {
  description = "Name of the compute instance."
  value       = google_compute_instance.this.name
}

output "internal_ip" {
  description = "Internal IP address of the instance."
  value       = google_compute_instance.this.network_interface[0].network_ip
}

output "external_ip" {
  description = "External (public) IP address, or null when the instance has none."
  value       = var.static_public_ip ? google_compute_address.this[0].address : null
}

output "network_id" {
  description = "ID of the created VPC network."
  value       = google_compute_network.this.id
}

output "subnet_id" {
  description = "ID of the created subnetwork."
  value       = google_compute_subnetwork.this.id
}

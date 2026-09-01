output "network_name" {
  description = "Nama VPC network."
  value       = google_compute_network.main.name
}

output "network_self_link" {
  description = "Self-link VPC network."
  value       = google_compute_network.main.self_link
}

output "subnet_name" {
  description = "Nama subnet."
  value       = google_compute_subnetwork.main.name
}

output "subnet_self_link" {
  description = "Self-link subnet."
  value       = google_compute_subnetwork.main.self_link
}

output "router_name" {
  description = "Nama Cloud Router."
  value       = google_compute_router.main.name
}

output "nat_name" {
  description = "Nama Cloud NAT."
  value       = google_compute_router_nat.main.name
}

output "subnet_pods_range_name" {
  description = "Nama secondary range pods (untuk GKE ip_allocation_policy)."
  value       = var.subnet_pods_range_name
}

output "subnet_services_range_name" {
  description = "Nama secondary range services (untuk GKE ip_allocation_policy)."
  value       = var.subnet_services_range_name
}

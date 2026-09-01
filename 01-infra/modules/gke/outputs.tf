output "cluster_name" {
  description = "Nama GKE cluster."
  value       = google_container_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint API cluster (untuk kubectl)."
  value       = google_container_cluster.main.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "CA certificate cluster (base64)."
  value       = google_container_cluster.main.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "Location (zone/region) cluster."
  value       = google_container_cluster.main.location
}

output "get_credentials_command" {
  description = "Perintah gcloud untuk mendapatkan kubectl credentials."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --zone ${google_container_cluster.main.location} --project ${var.project_id}"
}

output "node_pool_sa_email" {
  description = "Email SA node pool (untuk IAM binding Workload Identity nanti)."
  value       = google_service_account.gke_nodes.email
}

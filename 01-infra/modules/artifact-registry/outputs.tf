output "repository_id" {
  description = "ID repository Artifact Registry"
  value       = google_artifact_registry_repository.main.repository_id
}

output "repository_name" {
  description = "Full name resource repository"
  value       = google_artifact_registry_repository.main.name
}

output "registry_url" {
  description = "URL registry untuk docker push/pull (tanpa tag)"
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"
}

output "location" {
  description = "Region registry"
  value       = google_artifact_registry_repository.main.location
}

# Module: artifact-registry
# Membuat Google Artifact Registry repository untuk Docker images.
# Digunakan oleh CI (Jenkins) untuk push image dan GKE untuk pull image.

resource "google_artifact_registry_repository" "main" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  description   = var.description
  format        = "DOCKER"

  labels = var.labels

  # Cleanup policy — hapus image lama agar tidak membengkak
  dynamic "cleanup_policies" {
    for_each = var.enable_cleanup_policy ? [1] : []
    content {
      id     = "keep-minimum-versions"
      action = "KEEP"
      most_recent_versions {
        keep_count = var.keep_count
      }
    }
  }

  dynamic "cleanup_policies" {
    for_each = var.enable_cleanup_policy ? [1] : []
    content {
      id     = "delete-old-untagged"
      action = "DELETE"
      condition {
        tag_state = "UNTAGGED"
        older_than = "${var.untagged_retention_days * 24}h"
      }
    }
  }

  lifecycle {
    prevent_destroy = true  # AD-18: jangan hapus registry tanpa disengaja
  }
}

# IAM: beri GKE node SA akses pull image
resource "google_artifact_registry_repository_iam_member" "gke_node_reader" {
  count = var.gke_node_sa_email != "" ? 1 : 0

  project    = var.project_id
  location   = var.location
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.gke_node_sa_email}"
}

# IAM: beri Jenkins VM SA akses push image
resource "google_artifact_registry_repository_iam_member" "jenkins_writer" {
  count = var.jenkins_sa_email != "" ? 1 : 0

  project    = var.project_id
  location   = var.location
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.jenkins_sa_email}"
}

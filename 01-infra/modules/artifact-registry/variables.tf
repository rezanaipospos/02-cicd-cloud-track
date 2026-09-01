variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "Region untuk Artifact Registry (misal: asia-southeast1)"
  type        = string
}

variable "repository_id" {
  description = "ID repository (nama unik dalam project+region)"
  type        = string
  default     = "docker-images-repo"
}

variable "description" {
  description = "Deskripsi repository"
  type        = string
  default     = "Docker images untuk course CI/CD pipeline"
}

variable "labels" {
  description = "Labels GCP resource"
  type        = map(string)
  default     = {}
}

variable "enable_cleanup_policy" {
  description = "Aktifkan cleanup policy untuk hapus image lama"
  type        = bool
  default     = true
}

variable "keep_count" {
  description = "Jumlah image terbaru yang dipertahankan per tag"
  type        = number
  default     = 10
}

variable "untagged_retention_days" {
  description = "Jumlah hari image untagged dipertahankan sebelum dihapus"
  type        = number
  default     = 7
}

variable "gke_node_sa_email" {
  description = "Email Service Account GKE node pool (untuk IAM reader). Kosongkan jika tidak perlu."
  type        = string
  default     = ""
}

variable "jenkins_sa_email" {
  description = "Email Service Account Jenkins VM (untuk IAM writer). Kosongkan jika tidak perlu."
  type        = string
  default     = ""
}

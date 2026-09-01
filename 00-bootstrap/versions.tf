terraform {
  required_version = ">= 1.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # CATATAN (chicken-and-egg):
  # Stage 00-bootstrap inilah yang MEMBUAT bucket state. Karena itu stage ini
  # sengaja TIDAK memakai blok `backend "gcs"` — ia berjalan dengan local state.
  # Setelah bucket terbuat, stage berikutnya (01-infra, dst.) memakai backend GCS
  # mengikuti contoh di backend.tf.example.
}

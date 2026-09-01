# Component: artifact-registry
# GCP Artifact Registry untuk menyimpan Docker images CI/CD pipeline.
# State terpisah; tidak ada dependency ke module lain (standalone resource).
#
# PESERTA: edit nilai di inputs{} sesuai kebutuhan.
# Jangan ubah modules/artifact-registry/*.tf langsung.

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules/artifact-registry"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  # --- Repository config ---
  repository_id = "docker-images-course"   # nama repo (match dengan pipeline.yaml registry.repository)
  location      = local.env.locals.region  # region sama dengan GKE cluster
  description   = "Docker images untuk course CI/CD pipeline"

  # --- Cleanup policy: hemat storage ---
  enable_cleanup_policy   = true
  keep_count              = 2   # pertahankan 10 image terbaru per repo
  untagged_retention_days = 7    # hapus untagged image setelah 7 hari

  # --- IAM bindings ---
  # Isi setelah GKE + Jenkins VM ter-provision
  # Output dari: cd gke && terragrunt output node_pool_sa_email
  gke_node_sa_email = "gke-course-dev-nodes@nsr-devops.iam.gserviceaccount.com"  # <- GANTI: "sa-gke-node@YOUR_PROJECT.iam.gserviceaccount.com"

  # SA Jenkins VM jika menggunakan SA dedicated (bukan default compute SA)
  # Jika Jenkins pakai docker auth dengan gcloud, biarkan kosong dan
  # berikan role artifactregistry.writer ke SA VM lewat compute module.
  jenkins_sa_email = "sa-vm-jenkins@nsr-devops.iam.gserviceaccount.com"   # <- GANTI jika Jenkins punya dedicated SA

  # --- Labels ---
  labels = {
    managed_by  = "terraform"
    course      = "be-a-devops-employee"
    environment = "dev"
    component   = "artifact-registry"
  }
}

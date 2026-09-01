# Konfigurasi per-environment (dev). Edit nilai di bawah sesuai project-mu.
# Ini analog dengan terraform.tfvars, tapi untuk Terragrunt.
# Tidak memuat secret → aman di-commit. Untuk nilai rahasia, gunakan TF_VAR_* / env.
locals {
  project_id = "nsr-devops"
  region     = "asia-southeast1"
  zone       = "asia-southeast1-a"

  # Output dari stage 00-bootstrap:
  state_bucket       = "rnd-devops-tf"
  terraform_sa_email = "sa-terraform@nsr-devops.iam.gserviceaccount.com"
}

# =============================================================================
# Root Terragrunt config untuk stage 01-infra.
# Menghasilkan backend.tf + provider.tf untuk setiap unit (component),
# sehingga setiap component punya state TERPISAH.
#
# Manfaat:
# - Ubah 1 component (mis. compute) → plan/apply hanya menyentuh state-nya saja (cepat).
# - Tidak ada lagi "comment module = destroy"; tiap component punya lifecycle sendiri.
# - `terragrunt run-all apply` dari environments/<env>/ tetap bisa apply semua sekaligus
#   dengan urutan otomatis dari blok `dependency`.
# =============================================================================

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  project_id         = local.env.locals.project_id
  region             = local.env.locals.region
  state_bucket       = local.env.locals.state_bucket
  terraform_sa_email = local.env.locals.terraform_sa_email
}

# State remote per-component (prefix unik dari path relatif unit).
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket                      = local.state_bucket
    prefix                      = "${path_relative_to_include()}/terraform.tfstate"
    project                     = local.project_id
    location                    = local.region
    impersonate_service_account = local.terraform_sa_email
  }
}

# Provider di-generate seragam untuk semua component.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "google" {
  project = "${local.project_id}"
  region  = "${local.region}"
}
EOF
}

# Input umum yang diteruskan ke semua module.
inputs = {
  project_id = local.project_id
  region     = local.region
}

# Component: kms
# GCP Cloud KMS Key Ring, Crypto Key, dan Service Account untuk Vault Auto-Unseal.

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules/kms"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  project_id = local.env.locals.project_id
  location   = local.env.locals.region

  key_ring_name      = "vault-unseal"
  crypto_key_name    = "vault-unseal-key"
  service_account_id = "vault-sa"

  vault_namespace            = "vault"
  vault_service_account_name = "vault"

  labels = {
    managed_by  = "terraform"
    course      = "be-a-devops-employee"
    environment = "dev"
    component   = "vault-kms"
  }
}

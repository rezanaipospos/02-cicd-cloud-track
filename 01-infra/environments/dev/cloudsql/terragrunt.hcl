# Component: cloudsql (PostgreSQL, Private IP, IAM Auth)
# Ketergantungan: network (karena butuh Private Service Access VPC Peering)

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules/cloudsql"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

# --- Dependencies ---
# Modul cloudsql membutuhkan network (dan VPC peering) agar bisa assign Private IP
dependency "network" {
  config_path = "../network"

  mock_outputs = {
    network_self_link = "projects/mock/global/networks/vpc-mock"
  }
}

inputs = {
  instance_name = "course-pg-dev"
  
  # Inject VPC ID dari output modul network
  vpc_id = dependency.network.outputs.network_self_link

  # Konfigurasi Workload Identity
  iam_service_account_name = "backend-go-db-sa"
  k8s_namespace            = "backend-development"
  k8s_service_account_name = "backend-go"

  # Standard user untuk backend-go-cinema
  standard_db_user     = "cinema-dev-user"
  standard_db_password = "cinema-secure-password" # Di prod, gunakan secret manager/sops

  enable_deletion_protection = false # False untuk memudahkan lab/teardown
}

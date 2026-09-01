# Component: network (VPC + subnet + Cloud NAT + firewall IAP)
# State terpisah → perubahan di sini tidak men-scan component lain.
#
# SEMUA variabel configurable di-pass eksplisit di sini (AD-2: parameterisasi penuh).
# Peserta cukup edit file INI saja — tidak perlu ubah modules/network/variables.tf.

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules/network"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  # --- Identifiers ---
  network_name      = "vpc-course-dev"
  subnet_name       = "subnet-course-dev"
  router_name       = "router-course-dev"
  nat_name          = "nat-course-dev"
  nat_ip_name       = "address-nat-dev"
  firewall_iap_name = "allow-iap"
  firewall_webhook_name = "allow-github-webhook"

  # =========================================================================
  # CATATAN SETUP PRODUCTION (Cloud NAT Tuning):
  # =========================================================================
  # Jika men-deploy ke lingkungan Production, tambahkan/aktifkan nilai ini di inputs:
  #   enable_dynamic_port_allocation = true
  #   min_ports_per_vm               = 1024
  # =========================================================================

  # --- Subnet primary CIDR ---
  subnet_cidr = "10.10.0.0/24"

  # --- Secondary ranges untuk GKE pods & services ---
  # Dipakai oleh module GKE (dependency → ambil range name dari output network)
  subnet_pods_range_name     = "gke-pods"
  subnet_pods_cidr           = "10.20.0.0/16"   # /16 = 65536 IPs (cegah IP exhaustion)
  subnet_services_range_name = "gke-services"
  subnet_services_cidr       = "10.30.0.0/20"   # /20 = 4096 IPs (jarang habis)

  # --- Webhook firewall (GitHub webhook IPs + IP admin) ---
  # Ambil dari https://api.github.com/meta → hooks
  # Tambah IP admin kamu untuk akses Jenkins UI via HTTPS
  webhook_allowed_cidrs = [
    "140.82.112.0/20",   # GitHub hooks
    "185.199.108.0/22",  # GitHub hooks
    "192.30.252.0/22",   # GitHub hooks
    # "YOUR_PUBLIC_IP/32",  # ← GANTI dengan IP admin kamu
  ]

  # --- Labels ---
  labels = {
    managed_by  = "terraform"
    course      = "be-a-devops-employee"
    environment = "dev"
  }
}

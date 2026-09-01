# Component: gke (GKE cluster production-grade)
# State terpisah; dependency ke network.
#
# SEMUA variabel configurable di-pass eksplisit di sini (AD-2: parameterisasi penuh).
# Peserta cukup edit file INI saja — tidak perlu ubah modules/gke/variables.tf.

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules/gke"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    network_self_link          = "projects/mock/global/networks/mock"
    subnet_self_link           = "projects/mock/regions/mock/subnetworks/mock"
    subnet_pods_range_name     = "gke-pods"
    subnet_services_range_name = "gke-services"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  # --- Cluster config ---
  zone         = local.env.locals.zone
  cluster_name = "gke-course-dev"

  # --- Networking (dari dependency network) ---
  network_self_link   = dependency.network.outputs.network_self_link
  subnet_self_link    = dependency.network.outputs.subnet_self_link
  pods_range_name     = dependency.network.outputs.subnet_pods_range_name
  services_range_name = dependency.network.outputs.subnet_services_range_name

  # --- Private cluster: master CIDR (harus /28, tidak overlap subnet lain) ---
  master_ipv4_cidr_block = "172.16.0.0/28"

  # --- Authorized networks (siapa yang boleh kubectl ke cluster) ---
  # Tambah IP publik VM Jenkins (agar CI bisa kubectl) + IP admin kamu
  master_authorized_cidrs = [
    { cidr = "0.0.0.0/0", name = "all" }
    # { cidr = "103.119.142.178/32", name = "balifiber" },
    # { cidr = "35.247.189.80/32", name="argocd-cluster"}
    # Tip: setelah apply network+compute, ambil public IP dari output compute
  ]

  # --- Node pool config ---
  node_pool_name = "course-pool"
  machine_type   = "e2-medium"
  disk_size_gb   = 30
  min_node_count = 1
  max_node_count = 5
  preemptible    = true    # 60-91% lebih murah; node bisa di-preempt kapan saja

  # --- Max pods per node (cegah IP exhaustion) ---
  max_pods_per_node = 64

  # --- Logging ---
  logging_components = ["SYSTEM_COMPONENTS"]  # tambah "WORKLOADS" jika perlu (lebih mahal)

  # --- Upgrade notifications ---
  upgrade_notifications_topic = "gke-course-upgrade-notifications"

  # --- Destroy protection (AD-18) ---
  enable_destroy_protection = true  # set false hanya untuk teardown yang disengaja

  # --- Labels ---
  labels = {
    managed_by  = "terraform"
    course      = "be-a-devops-employee"
    environment = "dev"
  }
}

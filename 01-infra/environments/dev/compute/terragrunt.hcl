# Component: compute (VM Jenkins + dedicated SA + reserved IPs, akses via IAP)
# Bergantung pada output component network.
#
# SEMUA variabel configurable di-pass eksplisit di sini (AD-2: parameterisasi penuh).
# Peserta cukup edit file INI saja — tidak perlu ubah modules/compute/variables.tf.
#
# ⚠️ SETTINGAN YANG TIDAK BISA DIUBAH SETELAH APPLY (force recreate VM):
#   - zone, image, disk_type, preemptible, network/subnet
#   Pastikan benar SEBELUM pertama kali apply!

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules/compute"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    network_self_link = "projects/mock/global/networks/mock-vpc"
    subnet_self_link  = "projects/mock/regions/mock/subnetworks/mock-subnet"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  # --- Region/Zone (⚠️ zone = force recreate jika diubah) ---
  region = local.env.locals.region
  zone   = local.env.locals.zone

  # --- Instance config ---
  instance_name = "vm-jenkins-dev"
  machine_type  = "e2-medium"     # bisa diubah setelah apply (VM stop sementara)
  image         = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"  # ⚠️ force recreate
  disk_size_gb  = 20              # bisa diperbesar, tidak bisa dikecilkan
  disk_type     = "pd-standard"   # HDD — murah ($0.04/GB/bulan). ⚠️ force recreate

  # --- Spot/Preemptible (⚠️ force recreate jika diubah!) ---
  # 60-91% lebih murah, tapi VM bisa di-preempt kapan saja (maks 24 jam).
  # Build Jenkins yang sedang jalan bisa terputus. Acceptable untuk lab.
  # Set false untuk production yang butuh uptime stabil.
  preemptible = true

  # --- Networking (dari dependency network) ---
  network_self_link = dependency.network.outputs.network_self_link
  subnet_self_link  = dependency.network.outputs.subnet_self_link

  # --- IP publik reserved (stabil untuk DNS, webhook, TLS cert) ---
  # IP akan di-reserve secara otomatis dan tidak berubah meskipun VM di-stop/start.
  # Pakai IP ini untuk set DNS A record: jenkins.yourdomain.com → IP ini
  enable_public_ip = true

  # --- Dedicated SA (least privilege) ---
  vm_sa_account_id = "sa-vm-jenkins"
  vm_sa_roles = [
    "roles/logging.logWriter",          # kirim log ke Cloud Logging
    "roles/monitoring.metricWriter",    # kirim metrics ke Cloud Monitoring
    "roles/artifactregistry.reader",    # pull image dari Artifact Registry (Kaniko)
  ]

  # --- Network tags (harus match firewall target_tags di module network) ---
  network_tags = ["allow-iap-ssh", "allow-webhook"]

  # --- VM Metadata ---
  # enable-oslogin: TRUE = OS Login (production-grade, audit trail, tanpa manage SSH key)
  #                 FALSE = SSH key tradisional (lebih simple, cocok jika org GCP ribet)
  metadata = {
    enable-oslogin = "FALSE"   # ← set TRUE jika sudah grant roles/compute.osAdminLogin
  }

  # --- Labels ---
  labels = {
    managed_by  = "terraform"
    course      = "be-a-devops-employee"
    environment = "dev"
    role        = "jenkins"
  }

  # --- Backup Schedule (opsional) ---
  # Set enable_backup = true untuk aktifkan snapshot otomatis.
  # Default: false (hemat biaya untuk lab). Set true untuk production.
  # Biaya: ~$0.026/GB/bulan per snapshot yang disimpan.
  enable_backup         = false          # ← set true jika mau backup
  backup_frequency      = "daily"        # daily | weekly | hourly
  backup_start_time     = "02:00"        # UTC (09:00 WIB = 02:00 UTC)
  backup_days_in_cycle  = 1              # setiap 1 hari (hanya untuk daily)
  backup_day_of_week    = "SUNDAY"       # hanya untuk weekly
  backup_hours_in_cycle = 6              # setiap 6 jam (hanya untuk hourly)
  backup_retention_days = 7              # simpan snapshot selama 7 hari
}

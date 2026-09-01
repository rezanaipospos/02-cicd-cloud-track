# =============================================================================
# Module: compute
# VM generik + dedicated Service Account (least-privilege) + reserved IPs.
# Reusable untuk VM apapun (Jenkins, bastion, app server, dll).
# Diakses via IAP (Identity-Aware Proxy).
#
# CATATAN SETTINGAN YANG TIDAK BISA DIUBAH TANPA RECREATE VM:
# - zone
# - boot_disk image, disk_type
# - network/subnetwork
# - scheduling.provisioning_model (spot ↔ on-demand)
# - network_ip (IP internal reserved)
# Ubah salah satu di atas = Terraform akan destroy+recreate VM!
# Pastikan settingan ini benar SEBELUM pertama kali apply.
# =============================================================================

# --- Reserved Static Public IP (stabil untuk DNS, webhook, TLS cert) ---
resource "google_compute_address" "public" {
  count = var.enable_public_ip ? 1 : 0

  project      = var.project_id
  name         = "${var.instance_name}-public-ip"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"

  labels = var.labels
}

# --- Reserved Static Internal IP (stabil untuk Ansible, referensi antar-service) ---
resource "google_compute_address" "internal" {
  project      = var.project_id
  name         = "${var.instance_name}-internal-ip"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = var.subnet_self_link
  purpose      = "GCE_ENDPOINT"

  labels = var.labels
}

# --- Dedicated Service Account (least privilege, generik) ---
resource "google_service_account" "vm" {
  project      = var.project_id
  account_id   = var.vm_sa_account_id
  display_name = "Dedicated SA for ${var.instance_name}"
}

resource "google_project_iam_member" "vm_roles" {
  for_each = toset(var.vm_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.vm.email}"
}

# --- VM Instance ---
resource "google_compute_instance" "main" {
  project      = var.project_id
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_size_gb
      type  = var.disk_type
    }
  }

  network_interface {
    network    = var.network_self_link
    subnetwork = var.subnet_self_link

    # IP internal reserved (stabil — tidak berubah saat VM stop/start)
    network_ip = google_compute_address.internal.address

    # IP publik reserved (stabil untuk DNS, webhook, cert)
    dynamic "access_config" {
      for_each = var.enable_public_ip ? [1] : []
      content {
        nat_ip = google_compute_address.public[0].address
      }
    }
  }

  metadata = var.metadata

  # Dedicated SA (least privilege) — bukan default compute SA
  service_account {
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"]
  }

  labels = var.labels
  tags   = var.network_tags

  # Spot VM (opsional) — 60-91% lebih murah tapi bisa di-preempt.
  scheduling {
    preemptible                 = var.preemptible
    automatic_restart           = var.preemptible ? false : true
    on_host_maintenance         = var.preemptible ? "TERMINATE" : "MIGRATE"
    provisioning_model          = var.preemptible ? "SPOT" : "STANDARD"
    instance_termination_action = var.preemptible ? "STOP" : null
  }

  # Mencegah recreate VM saat metadata kecil berubah.
  allow_stopping_for_update = true

  # ⚠️ PROTEKSI DESTROY (AD-18): VM stateful.
  # Untuk destroy: comment block ini, lalu apply.
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      metadata["ssh-keys"],
    ]
  }
}

# =============================================================================
# Backup Schedule (Snapshot Policy) — opsional, configurable via variabel.
# Toggle: var.enable_backup (default false untuk lab, set true untuk production).
# =============================================================================

resource "google_compute_resource_policy" "backup" {
  count = var.enable_backup ? 1 : 0

  project = var.project_id
  name    = "${var.instance_name}-backup-policy"
  region  = var.region

  snapshot_schedule_policy {
    schedule {
      dynamic "daily_schedule" {
        for_each = var.backup_frequency == "daily" ? [1] : []
        content {
          days_in_cycle = var.backup_days_in_cycle
          start_time    = var.backup_start_time
        }
      }

      dynamic "weekly_schedule" {
        for_each = var.backup_frequency == "weekly" ? [1] : []
        content {
          day_of_weeks {
            day        = var.backup_day_of_week
            start_time = var.backup_start_time
          }
        }
      }

      dynamic "hourly_schedule" {
        for_each = var.backup_frequency == "hourly" ? [1] : []
        content {
          hours_in_cycle = var.backup_hours_in_cycle
          start_time     = var.backup_start_time
        }
      }
    }

    retention_policy {
      max_retention_days    = var.backup_retention_days
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }

    snapshot_properties {
      labels = merge(var.labels, {
        backup_source = var.instance_name
      })
      storage_locations = [var.region]
    }
  }
}

resource "google_compute_disk_resource_policy_attachment" "backup" {
  count = var.enable_backup ? 1 : 0

  project = var.project_id
  name    = google_compute_resource_policy.backup[0].name
  disk    = google_compute_instance.main.name
  zone    = var.zone
}

# =============================================================================
# Stage 00 — Bootstrap
# Membuat fondasi project: enable API, bucket state GCS, dan service account
# yang akan di-impersonate oleh Terraform pada stage berikutnya.
# Berjalan dengan LOCAL state (lihat catatan di versions.tf).
# =============================================================================

# 1) Aktifkan API yang dibutuhkan seluruh course.
resource "google_project_service" "enabled" {
  for_each = toset(var.enabled_apis)

  project = var.project_id
  service = each.value

  # Jangan menonaktifkan API saat destroy — mencegah teardown melumpuhkan project.
  disable_on_destroy = false
}

# 2) Bucket GCS untuk Terraform remote state stage berikutnya.
resource "google_storage_bucket" "tf_state" {
  name     = var.state_bucket_name
  project  = var.project_id
  location = var.region

  # Best practice keamanan & keselamatan state:
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  labels = var.labels

  # ⚠️ PROTEKSI DESTROY (AD-18): State bucket kritis — kehilangan = kehilangan seluruh state.
  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.enabled]
}

# 3) Service account yang akan di-impersonate oleh Terraform (tanpa key file).
resource "google_service_account" "terraform" {
  project      = var.project_id
  account_id   = var.terraform_sa_account_id
  display_name = "Terraform automation service account"

  depends_on = [google_project_service.enabled]
}

# 4) Role untuk SA Terraform agar bisa provisioning stage berikutnya.
resource "google_project_iam_member" "terraform_sa_roles" {
  for_each = toset(var.terraform_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

# 5) Izinkan identitas tertentu meng-impersonate SA Terraform (tanpa key file).
resource "google_service_account_iam_member" "impersonation" {
  for_each = toset(var.impersonator_members)

  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.value
}

# =============================================================================
# 6) IAM Deny Policy — blokir SA Terraform dari delete resource stateful (AD-18).
# SA tetap bisa create/update, tapi TIDAK bisa destroy resource kritis.
# Toggle: var.enable_terraform_destroy_deny (default true).
# Anti self-bypass: SA tidak punya roles/iam.denyAdmin → tidak bisa hapus policy ini.
# =============================================================================
resource "google_iam_deny_policy" "terraform_no_destroy" {
  count = var.enable_terraform_destroy_deny ? 1 : 0

  parent       = urlencode("cloudresourcemanager.googleapis.com/projects/${var.project_id}")
  name         = "terraform-no-destroy-stateful"
  display_name = "Deny destroy of stateful resources for Terraform SA"

  rules {
    deny_rule {
      denied_principals = [
        "principal://iam.googleapis.com/projects/-/serviceAccounts/${google_service_account.terraform.email}"
      ]
      denied_permissions = [
        "compute.googleapis.com/networks.delete",
        "compute.googleapis.com/subnetworks.delete",
        "compute.googleapis.com/instances.delete",
        "container.googleapis.com/clusters.delete",
        "storage.googleapis.com/buckets.delete",
      ]
    }
  }

  depends_on = [google_service_account.terraform]
}

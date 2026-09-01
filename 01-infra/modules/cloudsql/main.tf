# =============================================================================
# Module: cloudsql
# Provisioning PostgreSQL instance dengan Private IP, SSL, dan IAM Auth
# =============================================================================

resource "google_sql_database_instance" "main" {
  name             = var.instance_name
  database_version = var.database_version
  region           = var.region
  project          = var.project_id

  # Deletion protection untuk production (disarankan true)
  deletion_protection = var.enable_deletion_protection

  settings {
    tier = var.tier # Contoh: db-f1-micro untuk hemat biaya

    # Mengaktifkan Private IP (membutuhkan modul network PSA)
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_id
      require_ssl     = true # Wajib SSL
    }

    # Mengaktifkan IAM Workload Identity Authentication
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
  }
}

# Membuat database default
resource "google_sql_database" "default" {
  name     = var.db_name
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

# --- GCP Service Account untuk DB Access ---
resource "google_service_account" "db_sa" {
  account_id   = var.iam_service_account_name
  display_name = "CloudSQL Database Access Service Account (Workload Identity)"
  project      = var.project_id
}

# Memberikan akses CloudSQL Client
resource "google_project_iam_member" "sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.db_sa.email}"
}

# Memberikan akses CloudSQL Instance User
resource "google_project_iam_member" "sql_instance_user" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.db_sa.email}"
}

# Binding GSA ke KSA via Workload Identity
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.db_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account_name}]"
}

# Membuat user database berbasis IAM Service Account (Workload Identity)
# Format nama user PostgreSQL IAM: <sa-name>@<project-id>.iam
resource "google_sql_user" "iam_user" {
  name     = "${google_service_account.db_sa.account_id}@${var.project_id}.iam"
  instance = google_sql_database_instance.main.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
  project  = var.project_id

  depends_on = [google_service_account.db_sa]
}

# Membuat user database standar berbasis password (untuk backend-go-cinema)
resource "google_sql_user" "standard_user" {
  name     = var.standard_db_user
  password = var.standard_db_password
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

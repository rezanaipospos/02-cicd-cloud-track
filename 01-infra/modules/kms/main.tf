# Module: kms
# Membuat KMS Key Ring, Crypto Key, dan Service Account untuk Vault Auto-Unseal.
# Menghubungkan SA GCP ke SA GKE via Workload Identity.

# 1. KMS Key Ring
resource "google_kms_key_ring" "vault" {
  project  = var.project_id
  name     = var.key_ring_name
  location = var.location
}

# 2. KMS Crypto Key
resource "google_kms_crypto_key" "vault" {
  name     = var.crypto_key_name
  key_ring = google_kms_key_ring.vault.id
  purpose  = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = true # Proteksi data agar key tidak terhapus
  }
}

# 3. Service Account untuk Vault
resource "google_service_account" "vault" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "Vault Auto-Unseal Service Account"
}

# 4. KMS IAM Binding: Izinkan SA Vault meng-enkripsi/dekripsi dengan KMS Key
resource "google_kms_crypto_key_iam_member" "vault" {
  crypto_key_id = google_kms_crypto_key.vault.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.vault.email}"
}

resource "google_kms_crypto_key_iam_member" "vault_viewer" {
  crypto_key_id = google_kms_crypto_key.vault.id
  role          = "roles/cloudkms.viewer"
  member        = "serviceAccount:${google_service_account.vault.email}"
}

# 5. Workload Identity IAM Binding: Izinkan K8s SA 'vault' meng-impersonate GCP SA 'vault-sa'
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.vault.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.vault_namespace}/${var.vault_service_account_name}]"
}

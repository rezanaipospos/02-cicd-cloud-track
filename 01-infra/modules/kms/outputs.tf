output "key_ring_name" {
  value       = google_kms_key_ring.vault.name
  description = "Nama Key Ring"
}

output "crypto_key_name" {
  value       = google_kms_crypto_key.vault.name
  description = "Nama Crypto Key"
}

output "service_account_email" {
  value       = google_service_account.vault.email
  description = "Email Service Account"
}

output "kms_key_link" {
  value       = google_kms_crypto_key.vault.id
  description = "Resource Link ke KMS Crypto Key"
}

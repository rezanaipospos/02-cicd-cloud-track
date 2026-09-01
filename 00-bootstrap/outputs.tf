output "state_bucket_name" {
  description = "Nama bucket GCS untuk Terraform state. Pakai ini pada blok backend stage berikutnya."
  value       = google_storage_bucket.tf_state.name
}

output "terraform_service_account_email" {
  description = "Email service account yang di-impersonate Terraform pada stage berikutnya."
  value       = google_service_account.terraform.email
}

output "enabled_apis" {
  description = "Daftar API yang diaktifkan."
  value       = sort([for s in google_project_service.enabled : s.service])
}

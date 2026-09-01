output "instance_name" {
  description = "Nama VM instance."
  value       = google_compute_instance.main.name
}

output "instance_self_link" {
  description = "Self-link VM instance."
  value       = google_compute_instance.main.self_link
}

output "instance_zone" {
  description = "Zone tempat VM berjalan."
  value       = google_compute_instance.main.zone
}

output "instance_internal_ip" {
  description = "IP internal reserved (stabil — untuk Ansible inventory, referensi antar-service)."
  value       = google_compute_address.internal.address
}

output "instance_public_ip" {
  description = "IP publik reserved (stabil — untuk DNS, webhook URL, TLS cert). Kosong jika enable_public_ip=false."
  value       = var.enable_public_ip ? google_compute_address.public[0].address : ""
}

output "ssh_via_iap_command" {
  description = "Perintah SSH ke VM via IAP."
  value       = "gcloud compute ssh ${google_compute_instance.main.name} --tunnel-through-iap --zone ${google_compute_instance.main.zone} --project ${var.project_id}"
}

output "vm_service_account_email" {
  description = "Email dedicated SA VM (untuk referensi IAM binding di stage lain)."
  value       = google_service_account.vm.email
}

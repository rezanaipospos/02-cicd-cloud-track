variable "project_id" {
  type        = string
  description = "ID project GCP tempat fondasi dibuat."
}

variable "region" {
  type        = string
  description = "Region GCP default (juga lokasi bucket state)."
  default     = "asia-southeast1"
}

variable "state_bucket_name" {
  type        = string
  description = "Nama bucket GCS untuk menyimpan Terraform state stage berikutnya. Harus unik secara global."
}

variable "enabled_apis" {
  type        = list(string)
  description = "Daftar API GCP yang diaktifkan untuk seluruh course."
  default = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iap.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ]
}

variable "terraform_sa_account_id" {
  type        = string
  description = "Account ID (bagian sebelum @) untuk service account yang akan di-impersonate oleh Terraform."
  default     = "sa-terraform"
}

# CATATAN KEAMANAN (AD-18 — anti self-bypass):
# SA Terraform TIDAK boleh punya roles/iam.denyAdmin.
# Tanpa role itu, SA tidak bisa memodifikasi/menghapus IAM Deny Policy yang memblokir destroy.
# Jika butuh manage deny policy: gunakan akun admin langsung (bukan SA Terraform).
variable "terraform_sa_roles" {
  type        = list(string)
  description = "Role yang diberikan ke service account Terraform untuk provisioning stage berikutnya."
  default = [
    "roles/compute.admin",
    "roles/container.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/resourcemanager.projectIamAdmin",
    "roles/storage.admin",
  ]
}

variable "impersonator_members" {
  type        = list(string)
  description = "Identitas (mis. user:nama@gmail.com) yang boleh meng-impersonate service account Terraform. Kosongkan jika belum diatur."
  default     = []
}

variable "labels" {
  type        = map(string)
  description = "Label umum untuk resource."
  default = {
    managed_by = "terraform"
    course     = "be-a-devops-employee"
    stage      = "00-bootstrap"
  }
}

variable "enable_destroy_protection" {
  type        = bool
  description = "Toggle prevent_destroy lifecycle pada state bucket. prevent_destroy hardcoded true di main.tf; variabel ini untuk dokumentasi."
  default     = true
}

variable "enable_terraform_destroy_deny" {
  type        = bool
  description = "Toggle IAM Deny Policy yang memblokir SA Terraform dari delete resource stateful. Default true. Set false HANYA untuk teardown yang disengaja. CATATAN: SA Terraform TIDAK punya roles/iam.denyAdmin — tidak bisa memodifikasi deny policy ini sendiri (anti self-bypass)."
  default     = true
}

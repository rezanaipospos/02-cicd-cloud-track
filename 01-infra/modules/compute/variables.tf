variable "project_id" {
  type        = string
  description = "ID project GCP."
}

variable "region" {
  type        = string
  description = "Region GCP (untuk reserved IP address)."
}

variable "zone" {
  type        = string
  description = "Zone GCP untuk instance. ⚠️ TIDAK BISA diubah setelah apply (force recreate)."
}

variable "instance_name" {
  type        = string
  description = "Nama VM instance."
  default     = "vm-jenkins"
}

variable "machine_type" {
  type        = string
  description = "Machine type untuk VM. Bisa diubah setelah apply (VM akan stop sementara)."
  default     = "e2-medium"
}

variable "image" {
  type        = string
  description = "Boot disk image. ⚠️ TIDAK BISA diubah setelah apply (force recreate disk)."
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "disk_size_gb" {
  type        = number
  description = "Ukuran boot disk dalam GB. Bisa diperbesar (bukan dikecilkan) tanpa recreate."
  default     = 20
}

variable "disk_type" {
  type        = string
  description = "Tipe disk. pd-standard = HDD (murah), pd-ssd = SSD, pd-balanced = balanced. ⚠️ TIDAK BISA diubah setelah apply."
  default     = "pd-standard"
}

variable "preemptible" {
  type        = bool
  description = "Spot/preemptible VM (60-91% lebih murah). ⚠️ TIDAK BISA diubah setelah apply (force recreate). Spot VM bisa di-preempt kapan saja (maks 24 jam)."
  default     = true
}

variable "network_self_link" {
  type        = string
  description = "Self-link network tempat VM ditempatkan. ⚠️ TIDAK BISA diubah setelah apply."
}

variable "subnet_self_link" {
  type        = string
  description = "Self-link subnet tempat VM ditempatkan. ⚠️ TIDAK BISA diubah setelah apply."
}

variable "enable_public_ip" {
  type        = bool
  description = "Aktifkan reserved IP publik (untuk webhook/DNS). IP akan di-reserve (stabil, tidak berubah)."
  default     = true
}

variable "vm_sa_account_id" {
  type        = string
  description = "Account ID untuk dedicated Service Account VM. Harus unik per project."
  default     = "sa-vm-instance"
}

variable "vm_sa_roles" {
  type        = list(string)
  description = "Role IAM untuk dedicated SA VM (least privilege). Sesuaikan per use-case VM."
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ]
}

variable "network_tags" {
  type        = list(string)
  description = "Network tags untuk VM (harus match dengan firewall target_tags di module network)."
  default     = ["allow-iap-ssh"]
}

variable "metadata" {
  type        = map(string)
  description = "Metadata key-value pairs untuk VM. Set enable-oslogin=TRUE untuk OS Login (production), FALSE untuk SSH key tradisional."
  default = {
    enable-oslogin = "TRUE"
  }
}

variable "labels" {
  type        = map(string)
  description = "Label untuk VM dan resources terkait."
  default     = {}
}

variable "enable_destroy_protection" {
  type        = bool
  description = "Toggle destroy protection. prevent_destroy hardcoded true di main.tf; variabel ini untuk dokumentasi."
  default     = true
}

# =============================================================================
# Backup Schedule Variables
# =============================================================================

variable "enable_backup" {
  type        = bool
  description = "Aktifkan snapshot backup schedule untuk boot disk VM. Set false untuk lab (hemat biaya), true untuk production."
  default     = false
}

variable "backup_frequency" {
  type        = string
  description = "Frekuensi backup: 'daily', 'weekly', atau 'hourly'."
  default     = "daily"

  validation {
    condition     = contains(["daily", "weekly", "hourly"], var.backup_frequency)
    error_message = "backup_frequency harus salah satu dari: daily, weekly, hourly."
  }
}

variable "backup_start_time" {
  type        = string
  description = "Jam mulai backup (format HH:MM, UTC). Default 02:00 UTC (pagi, traffic rendah)."
  default     = "02:00"
}

variable "backup_days_in_cycle" {
  type        = number
  description = "Interval hari untuk daily schedule (1 = setiap hari, 2 = setiap 2 hari, dst). Hanya berlaku jika backup_frequency = 'daily'."
  default     = 1
}

variable "backup_day_of_week" {
  type        = string
  description = "Hari untuk weekly schedule. Hanya berlaku jika backup_frequency = 'weekly'."
  default     = "SUNDAY"

  validation {
    condition     = contains(["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"], var.backup_day_of_week)
    error_message = "backup_day_of_week harus hari dalam bahasa Inggris (uppercase)."
  }
}

variable "backup_hours_in_cycle" {
  type        = number
  description = "Interval jam untuk hourly schedule (mis. 6 = setiap 6 jam). Hanya berlaku jika backup_frequency = 'hourly'."
  default     = 6
}

variable "backup_retention_days" {
  type        = number
  description = "Berapa hari snapshot disimpan sebelum auto-delete. Default 7 hari."
  default     = 7
}

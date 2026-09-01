variable "project_id" {
  type        = string
  description = "ID project GCP."
}

variable "region" {
  type        = string
  description = "Region GCP untuk subnet dan NAT."
}

variable "network_name" {
  type        = string
  description = "Nama VPC network."
  default     = "vpc-main"
}

variable "subnet_name" {
  type        = string
  description = "Nama subnet."
  default     = "subnet-main"
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR range untuk subnet."
  default     = "10.10.0.0/24"
}

variable "subnet_pods_range_name" {
  type        = string
  description = "Nama secondary range untuk GKE pods."
  default     = "gke-pods"
}

variable "subnet_pods_cidr" {
  type        = string
  description = "CIDR secondary range pods. /16 = 65536 IPs (cegah IP exhaustion saat scale)."
  default     = "10.20.0.0/16"
}

variable "subnet_services_range_name" {
  type        = string
  description = "Nama secondary range untuk GKE services."
  default     = "gke-services"
}

variable "subnet_services_cidr" {
  type        = string
  description = "CIDR secondary range services. /20 = 4096 IPs (jarang habis)."
  default     = "10.30.0.0/20"
}

variable "router_name" {
  type        = string
  description = "Nama Cloud Router."
  default     = "router-main"
}

variable "nat_name" {
  type        = string
  description = "Nama Cloud NAT."
  default     = "nat-main"
}

variable "nat_ip_name" {
  type        = string
  description = "Nama reserved static IP address untuk Cloud NAT."
  default     = "address-nat-main"
}

variable "firewall_iap_name" {
  type        = string
  description = "Nama firewall rule untuk IAP SSH."
  default     = "allow-iap-ssh"
}

variable "firewall_webhook_name" {
  type        = string
  description = "Nama firewall rule untuk GitHub webhook (HTTPS 443)."
  default     = "allow-github-webhook"
}

variable "webhook_allowed_cidrs" {
  type        = list(string)
  description = "CIDR yang boleh akses port 443 (GitHub webhook IPs + IP admin). Ambil dari https://api.github.com/meta -> hooks."
  default = [
    # GitHub hooks (per https://api.github.com/meta, sering berubah — verifikasi sebelum apply)
    "140.82.112.0/20",
    "185.199.108.0/22",
    "192.30.252.0/22",
    # Tambah IP admin kamu di sini:
    # "YOUR_PUBLIC_IP/32",
  ]
}

variable "labels" {
  type        = map(string)
  description = "Label umum (tidak dipakai oleh semua resource, tersedia untuk konsistensi)."
  default     = {}
}

variable "enable_destroy_protection" {
  type        = bool
  description = "Toggle untuk prevent_destroy lifecycle pada VPC dan subnet. Default true untuk produksi. Set false HANYA untuk teardown yang disengaja (harus edit kode + apply terlebih dahulu)."
  default     = true
}

variable "psa_range_name" {
  type        = string
  description = "Nama reserved IP range untuk Private Service Access (CloudSQL, dll)."
  default     = "google-managed-services-range"
}

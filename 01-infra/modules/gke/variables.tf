variable "project_id" {
  type        = string
  description = "ID project GCP."
}

variable "region" {
  type        = string
  description = "Region GCP."
}

variable "zone" {
  type        = string
  description = "Zone untuk zonal cluster (lebih murah). Kosongkan untuk regional."
  default     = ""
}

variable "cluster_name" {
  type        = string
  description = "Nama GKE cluster."
  default     = "gke-course-dev"
}

variable "network_self_link" {
  type        = string
  description = "Self-link VPC network."
}

variable "subnet_self_link" {
  type        = string
  description = "Self-link subnet."
}

variable "pods_range_name" {
  type        = string
  description = "Nama secondary range untuk pods."
}

variable "services_range_name" {
  type        = string
  description = "Nama secondary range untuk services."
}

variable "master_ipv4_cidr_block" {
  type        = string
  description = "CIDR untuk master (private cluster). Harus /28."
  default     = "172.16.0.0/28"
}

variable "master_authorized_cidrs" {
  type = list(object({
    cidr = string
    name = string
  }))
  description = "CIDR yang boleh akses kubectl ke cluster (authorized networks)."
  default = [
    # Cloud NAT IP (agar Jenkins bisa kubectl); tambah IP admin.
    # Isi dengan IP NAT dari output network + IP publik kamu.
  ]
}

variable "max_pods_per_node" {
  type        = number
  description = "Max pods per node (cegah IP exhaustion). Default 64."
  default     = 64
}

variable "node_pool_name" {
  type        = string
  description = "Nama node pool."
  default     = "course-pool"
}

variable "machine_type" {
  type        = string
  description = "Machine type node pool."
  default     = "e2-medium"
}

variable "disk_size_gb" {
  type        = number
  description = "Disk size per node (GB)."
  default     = 30
}

variable "min_node_count" {
  type        = number
  description = "Minimum nodes (autoscaling)."
  default     = 1
}

variable "max_node_count" {
  type        = number
  description = "Maximum nodes (autoscaling)."
  default     = 2
}

variable "preemptible" {
  type        = bool
  description = "Gunakan preemptible/spot nodes (60-91% lebih murah)."
  default     = true
}

variable "upgrade_notifications_topic" {
  type        = string
  description = "Nama Pub/Sub topic untuk upgrade notifications."
  default     = "gke-upgrade-notifications"
}

variable "logging_components" {
  type        = list(string)
  description = "Komponen logging. Default SYSTEM_COMPONENTS saja (WORKLOADS bisa mahal karena volume log pod besar)."
  default     = ["SYSTEM_COMPONENTS"]
}

variable "labels" {
  type        = map(string)
  description = "Label umum."
  default     = {}
}

variable "enable_destroy_protection" {
  type        = bool
  description = "Toggle GKE deletion_protection (native GCP). Default true untuk produksi. Set false + comment prevent_destroy lifecycle block untuk teardown yang disengaja."
  default     = true
}

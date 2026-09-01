variable "project_id" {
  type        = string
  description = "ID Project GCP."
}

variable "region" {
  type        = string
  description = "GCP Region."
}

variable "instance_name" {
  type        = string
  description = "Nama instance CloudSQL."
  default     = "postgres-course-db"
}

variable "database_version" {
  type        = string
  description = "Versi PostgreSQL."
  default     = "POSTGRES_15"
}

variable "tier" {
  type        = string
  description = "Machine type/tier untuk CloudSQL."
  default     = "db-f1-micro"
}

variable "vpc_id" {
  type        = string
  description = "Self link VPC network tempat CloudSQL di-peering (PSA)."
}

variable "db_name" {
  type        = string
  description = "Nama database awal."
  default     = "coursedb"
}

variable "iam_service_account_name" {
  type        = string
  description = "Nama GCP Service Account yang akan dibuat untuk akses database."
  default     = "backend-go-db-sa"
}

variable "k8s_namespace" {
  type        = string
  description = "Namespace Kubernetes tempat aplikasi dideploy."
  default     = "backend-development"
}

variable "k8s_service_account_name" {
  type        = string
  description = "Nama Kubernetes ServiceAccount aplikasi."
  default     = "backend-go"
}

variable "standard_db_user" {
  type        = string
  description = "Username standard password auth (untuk backend-go-cinema)."
  default     = "cinema-user"
}

variable "standard_db_password" {
  type        = string
  description = "Password standard user."
  sensitive   = true
}

variable "enable_deletion_protection" {
  type        = bool
  description = "Proteksi penghapusan database (set false untuk teardown course)."
  default     = false
}

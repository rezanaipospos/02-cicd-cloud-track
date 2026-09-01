variable "project_id" {
  type        = string
  description = "Project ID GCP"
}

variable "location" {
  type        = string
  description = "Lokasi Key Ring (region)"
  default     = "asia-southeast1"
}

variable "key_ring_name" {
  type        = string
  description = "Nama KMS Key Ring"
  default     = "vault-unseal"
}

variable "crypto_key_name" {
  type        = string
  description = "Nama KMS Crypto Key"
  default     = "vault-unseal-key"
}

variable "service_account_id" {
  type        = string
  description = "ID Service Account untuk Vault"
  default     = "vault-sa"
}

variable "vault_namespace" {
  type        = string
  description = "Namespace Vault di Kubernetes"
  default     = "vault"
}

variable "vault_service_account_name" {
  type        = string
  description = "Nama K8s Service Account Vault"
  default     = "vault"
}

variable "labels" {
  type        = map(string)
  description = "Labels untuk resource"
  default     = {}
}

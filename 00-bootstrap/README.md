# 00 — Bootstrap

**Prereq:** Onboarding (akun GCP aktif, billing aktif, `gcloud` & `terraform >= 1.7` terpasang, login `gcloud auth application-default login`).

## Tujuan
Menyiapkan fondasi GCP untuk seluruh course:
- Mengaktifkan API yang dibutuhkan.
- Membuat bucket GCS untuk **remote state** (versioning aktif).
- Membuat **service account Terraform** yang akan di-**impersonate** stage berikutnya (tanpa key file).

> **Penting (chicken-and-egg):** stage ini MEMBUAT bucket state, jadi ia berjalan dengan **local state** (tidak ada blok `backend "gcs"`). Stage berikutnya barulah memakai backend GCS — lihat `backend.tf.example`.

## Langkah
1. `cp terraform.tfvars.example terraform.tfvars`
2. Isi `project_id`, `region`, dan `state_bucket_name` (nama bucket harus unik global).
3. `terraform init`
4. `terraform plan`
5. `terraform apply`

## Verifikasi
- `terraform fmt -check` dan `terraform validate` lulus.
- Output `state_bucket_name` dan `terraform_service_account_email` muncul.
- Bucket terlihat di `gcloud storage ls`; API aktif di `gcloud services list --enabled`.

## Memakai output di stage berikutnya
Salin pola `backend.tf.example` ke `backend.tf` pada stage `01-infra` (dst.), isi `bucket` = `state_bucket_name`, `impersonate_service_account` = `terraform_service_account_email`, dan `prefix` unik per stage.

## Teardown
- `./teardown.sh` — jalankan **hanya** setelah seluruh stage lain di-teardown (ini menghapus bucket state).
- Karena `force_destroy = false`, kosongkan dulu isi bucket jika perlu sebelum destroy.

## Catatan biaya
- Bucket GCS + enable API: biaya mendekati nol. Service account: gratis. Aman untuk free-tier.

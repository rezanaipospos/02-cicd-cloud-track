# Stage 00 — Bootstrap (Terraform, local state)

**Tujuan:** membuat bucket GCS untuk state, enable API, dan service account Terraform (impersonation).

## Variabel yang WAJIB diisi

| Variabel | Contoh | Penjelasan |
|----------|--------|------------|
| `project_id` | `my-devops-course` | ID project GCP kamu (bukan nama) |
| `region` | `asia-southeast1` | Region GCP (default sudah ada) |
| `state_bucket_name` | `tf-state-my-devops-course` | Nama bucket GCS (harus **unik global**) |
| `impersonator_members` | `["user:kamu@gmail.com"]` | Email yang boleh impersonate SA Terraform |

## Langkah

```bash
cd course-project/00-bootstrap

# 1. Login ke GCP
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud auth application-default login

# 2. Salin file variabel & ISI NILAIMU
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars — isi 4 variabel di atas:
# project_id        = "my-devops-course"
# region            = "asia-southeast1"
# state_bucket_name = "tf-state-my-devops-course"
# impersonator_members = ["user:kamu@gmail.com"]

# 3. Init (local state — bootstrap belum pakai remote backend)
terraform init

# 4. Plan — review apa yang akan dibuat
terraform plan

# 5. Apply
terraform apply

# 6. CATAT OUTPUT (wajib untuk stage berikutnya!)
terraform output state_bucket_name
terraform output terraform_service_account_email
# Simpan kedua nilai ini — dipakai di env.hcl stage 01.
```

## Verifikasi
```bash
gcloud storage ls                       # bucket state harus terlihat
gcloud services list --enabled          # API (compute, container, iam, iap, dll) aktif
gcloud iam service-accounts list        # SA terraform terlihat
```

## Catatan penting
- Stage ini memakai **local state** (karena bucket belum ada). Setelah apply, stage berikutnya baru pakai backend GCS.
- `impersonator_members` memastikan akun kamu bisa meng-impersonate SA tanpa download key file.
- Jika ingin migrasi state bootstrap ke GCS juga: `terraform init -migrate-state` (opsional, advanced).

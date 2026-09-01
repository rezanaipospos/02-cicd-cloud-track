# Teardown / Destroy yang Disengaja (AD-18)

> ⚠️ **PERINGATAN:** Prosedur ini menghapus resource infrastructure. Pastikan benar-benar disengaja.
> Resource stateful dilindungi 3 lapisan — semua harus di-disable sebelum destroy berhasil.

## Lapisan proteksi yang aktif

| Lapisan | Mekanisme | Dimana | Toggle |
|---------|-----------|--------|--------|
| 1 | `lifecycle { prevent_destroy = true }` | `modules/*/main.tf` | Edit kode (comment block) |
| 2 | GKE `deletion_protection = true` | `modules/gke/main.tf` | `var.enable_destroy_protection = false` |
| 3 | IAM Deny Policy | `00-bootstrap/main.tf` | `var.enable_terraform_destroy_deny = false` |

## Prosedur destroy lengkap

```bash
# === STEP 1: Disable IAM Deny Policy (lapisan 3) ===
cd course-project/00-bootstrap
terraform apply -var="enable_terraform_destroy_deny=false"
# Verifikasi: gcloud iam policies list ... (deny policy tidak aktif)

# === STEP 2: Disable GKE deletion_protection (lapisan 2) ===
cd ../01-infra/environments/dev/gke
terragrunt apply -var="enable_destroy_protection=false"
# Verifikasi: gcloud container clusters describe ... --format="get(deletionProtection)"

# === STEP 3: Comment prevent_destroy lifecycle blocks (lapisan 1) ===
# Edit MANUAL di modules yang akan di-destroy:
# - modules/network/main.tf   → comment lifecycle block di VPC + subnet
# - modules/compute/main.tf   → comment lifecycle block di VM
# - modules/gke/main.tf       → comment lifecycle block di cluster
# - 00-bootstrap/main.tf      → comment lifecycle block di bucket (HANYA jika destroy bucket)
#
# Ini disengaja HIGH-FRICTION: destroy resource kritis harus butuh perubahan kode sadar.

# === STEP 4: Jalankan destroy ===
cd 01-infra/environments/dev
terragrunt run-all destroy   # atau per-component: cd gke && terragrunt destroy

# === STEP 5: Destroy bootstrap (TERAKHIR, setelah semua stage lain dihapus) ===
cd ../../00-bootstrap
./teardown.sh   # atau: terraform destroy

# === STEP 6: RE-ENABLE proteksi (jika tidak full teardown) ===
# - Uncomment lifecycle blocks
# - terraform apply -var="enable_terraform_destroy_deny=true" di bootstrap
# - terragrunt apply -var="enable_destroy_protection=true" di gke
```

## Teardown per-component (selektif)

```bash
# Hanya destroy GKE (sisanya tetap):
cd 01-infra/environments/dev/gke
# 1. Disable deny: cd ../../00-bootstrap && terraform apply -var="enable_terraform_destroy_deny=false"
# 2. Disable deletion_protection: terragrunt apply -var="enable_destroy_protection=false"
# 3. Comment prevent_destroy di modules/gke/main.tf
# 4. terragrunt destroy
# 5. Re-enable proteksi (uncomment + re-apply deny)
```

## Catatan biaya (teardown rekomendasi)

| Resource | Biaya/bulan (estimasi) | Teardown kapan? |
|----------|----------------------|-----------------|
| GKE node pool (preemptible) | ~$8-10 | Setelah selesai latihan GitOps/Vault |
| VM Jenkins | ~$8-10 | Setelah selesai course |
| Cloud NAT | ~$1-3 | Bersama VM |
| VPC/subnet | Gratis | Terakhir (atau biarkan) |
| State bucket | ~$0.02 | JANGAN hapus kecuali full teardown |

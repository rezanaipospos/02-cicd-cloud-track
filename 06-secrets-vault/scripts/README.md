# Scripts untuk Stage 06: Secret Management (Vault)

Script-script untuk setup dan konfigurasi Vault dengan GCP KMS auto-unseal.

## setup-kms.sh

Script untuk setup GCP Cloud KMS untuk Vault auto-unseal via Workload Identity.

### Prerequisites
- Google Cloud SDK (`gcloud`) terinstal dan terautentikasi
- Akses ke project GCP dengan permission untuk:
  - Membuat KMS key ring dan key
  - Membuat service account
  - Memberikan IAM role
- jq untuk parsing JSON (opsional)

### Usage
```bash
./setup-kms.sh [PROJECT_ID] [REGION]
```

### Contoh
```bash
# Dengan region default (asia-southeast1)
./setup-kms.sh my-gcp-project-id

# Dengan region spesifik
./setup-kms.sh my-gcp-project-id us-central1
```

### Apa yang dilakukan script:
1. **Memverifikasi prerequisites** - cek gcloud, login status
2. **Enable Cloud KMS API** - jika belum di-enable
3. **Buat KMS key ring** `vault-unseal` di region yang ditentukan
4. **Buat crypto key** `vault-unseal-key` untuk enkripsi/dekripsi
5. **Buat service account** `vault-sa` untuk Vault
6. **Bind IAM role** `cloudkms.cryptoKeyEncrypterDecrypter` ke service account
7. **Tampilkan konfigurasi** untuk Vault seal configuration

### Idempotensi
Script ini idempoten - bisa di-run multiple times tanpa error. Jika resource sudah ada, script akan skip pembuatan.

### Output yang dihasilkan
Setelah berhasil, script akan menampilkan:
- Detail konfigurasi (project, region, key ring, crypto key, service account)
- Resource path untuk Vault seal configuration
- Langkah selanjutnya untuk Workload Identity annotation
- Contoh konfigurasi untuk Vault Helm values

### Cleanup
Script menyertakan command untuk cleanup jika diperlukan:
- Hapus crypto key
- Hapus key ring
- Hapus service account

### Workload Identity Integration
Untuk integrasi dengan GKE Workload Identity:
1. Annotate Kubernetes ServiceAccount `vault` di namespace `vault`:
   ```bash
   kubectl annotate serviceaccount vault \
     --namespace vault \
     iam.gke.io/gcp-service-account=vault-sa@PROJECT_ID.iam.gserviceaccount.com
   ```

2. Pastikan Workload Identity sudah aktif di GKE cluster

3. Tambahkan annotation di Vault Helm values:
   ```yaml
   serviceAccount:
     annotations:
       iam.gke.io/gcp-service-account: "vault-sa@PROJECT_ID.iam.gserviceaccount.com"
   ```

### Vault Seal Configuration
Gunakan konfigurasi berikut di Vault Helm values:
```hcl
seal "gcpckms" {
  project     = "PROJECT_ID"
  region      = "REGION"
  key_ring    = "vault-unseal"
  crypto_key  = "vault-unseal-key"
}
```

### Catatan Keamanan
- Untuk lingkungan production, pertimbangkan menggunakan protection level `hsm` (Hardware Security Module)
- Pastikan service account hanya memiliki permission yang diperlukan
- Monitor penggunaan KMS key melalui Cloud Monitoring
- Rotate crypto key sesuai dengan kebijakan security organization
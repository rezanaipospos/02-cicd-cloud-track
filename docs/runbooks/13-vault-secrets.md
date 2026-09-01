# Stage 06 — Secret Management: HashiCorp Vault + External Secrets Operator

**Tujuan:** Mengelola secrets aplikasi menggunakan HashiCorp Vault secara terpusat dan aman. Secret di-inject ke pod saat runtime via External Secrets Operator (ESO) tanpa pernah di-bake ke dalam Docker image (AD-5, NFR-2).

---

## Arsitektur Secret Injection (Level 3 Security)

```
Build Time (Docker build TANPA .env) ──> Push image bersih ke Artifact Registry
                                                            │
GCP Cloud KMS (Auto-unseal) ──> HashiCorp Vault (HA Raft)  │ (Deploy)
                                     │                      │
                          External Secrets Operator ◄───────┘
                                     │ (Sync)
                            K8s Secret (Native)
                                     │ (Mount)
                        ┌────────────┴────────────┐
                        ▼                         ▼
                  [ envFrom ]               [ volumeMount ]
               (DB_URL, JWT, etc)       (banking_private_key.pem)
```

### Keunggulan Desain Ini (Level 3):
1. **No Baked Secrets:** Image identik lintas env, aman dari decompilation/inspection layer Docker.
2. **Multi-line RSA Key:** Private key finansial (`APP_BANKING_PRIVATE_KEY`) di-mount sebagai file dengan permission ketat (`0400`).
3. **Decoupled:** Aplikasi tidak terikat ke API Vault, hanya membaca env var dan file lokal standar.

---

## Step 1: Setup GCP KMS untuk Vault Auto-Unseal (As-Code)

Kita menggunakan Terragrunt untuk membuat Key Ring, Crypto Key, Service Account, dan IAM bindings yang diperlukan.

```bash
cd course-project/01-infra/environments/dev/kms

# 1. Jalankan Terragrunt apply (manual)
terragrunt apply
```

Output penting:
* Service Account: `vault-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com`
* Crypto Key: `projects/YOUR_PROJECT_ID/locations/asia-southeast1/keyRings/vault-unseal/cryptoKeys/vault-unseal-key`

---

## Step 2: Deploy Vault via ArgoCD (HA Raft Mode)

1. Pastikan file konfigurasi values Vault berada di `06-secrets-vault/vault/values.yaml` dengan KMS seal path yang sesuai.
2. Terapkan manifest Application Vault ke ArgoCD:
   ```bash
   cd course-project/05-gitops
   kubectl apply -f bootstrap/apps/vault.yaml
   ```
3. Tunggu hingga pods Vault Running:
   ```bash
   kubectl get pods -n vault
   # Expected: vault-0, vault-1, vault-2 Running (tapi status uninitialized)
   ```

### Inisialisasi Vault Sekali Saja (Manual)

Karena ini cluster baru, inisialisasi KMS auto-unseal Vault dilakukan secara manual sekali:
```bash
kubectl exec vault-0 -n vault -- vault operator init

# CATAT OUTPUTNYA DENGAN AMAN!
# Simpan Recovery Keys dan Initial Root Token.
```

Status unseal otomatis berhasil jika:
```bash
kubectl exec vault-0 -n vault -- vault status | grep -i sealed
# Expected: Sealed: false
```

---

## Step 3: Konfigurasi Vault As-Code (`vault-init.sh`)

Gunakan script init untuk mengaktifkan K8s Auth, KV secrets engine v2, dan policy untuk aplikasi.

```bash
cd course-project/06-secrets-vault/scripts

# Jalankan script post-init
./vault-init.sh
```

---

## Step 4: Isi Mock Secrets per Environment (`seed-secrets.sh`)

Script ini akan menghasilkan RSA private key dummy dan mengunggah database credentials, JWT secret, salt, New Relic key, dan private key tersebut ke Vault untuk dev, staging, dan prod.

```bash
cd course-project/06-secrets-vault/scripts

# Jalankan script seeding
./seed-secrets.sh
```

---

## Step 5: Deploy External Secrets Operator (ESO)

Deploy ESO via ArgoCD untuk menyinkronkan data dari Vault menjadi Kubernetes Secret native.

```bash
cd course-project/05-gitops
kubectl apply -f bootstrap/apps/external-secrets.yaml

# Tunggu pods ESO Running
kubectl get pods -n external-secrets
```

---

## Step 6: Verifikasi Sinkronisasi Secret

Setelah ArgoCD men-sync aplikasi `backend-go`, periksa apakah ESO berhasil membuat native Kubernetes Secret di namespace target:

```bash
# Periksa status sinkronisasi ExternalSecret
kubectl get externalsecret -n backend-development

# Periksa K8s Secret yang dihasilkan
kubectl get secret backend-go-secrets -n backend-development       # env vars
kubectl get secret backend-go-pem-secrets -n backend-development   # PEM file

# Verifikasi isi K8s Secret (Base64 decoded)
kubectl get secret backend-go-secrets -n backend-development -o jsonpath='{.data.APP_DB_URL}' | base64 -d
```

---

## Step 7: Verifikasi Injection di Pod App

1. Buka container pod aplikasi backend-go:
   ```bash
   kubectl exec -it deploy/backend-go-backend-go -n backend-development -- sh
   ```
2. Cek environment variables:
   ```bash
   env | grep APP_
   # Harus menampilkan: APP_DB_URL, APP_JWT_SECRET, APP_NEWRELIC_KEY, dll.
   ```
3. Cek file mount private key:
   ```bash
   cat /app/keys/banking_private_key.pem
   # Harus menampilkan isi RSA private key (-----BEGIN RSA PRIVATE KEY-----)
   ```
4. Cek file permissions (Level 3 Security):
   ```bash
   ls -la /app/keys/banking_private_key.pem
   # File permissions harus: -r-------- (0400)
   ```

---

## Teardown (Hapus resource)

```bash
# Hapus aplikasi ArgoCD
kubectl delete -f bootstrap/apps/vault.yaml
kubectl delete -f bootstrap/apps/external-secrets.yaml

# Hapus data persistent Vault
kubectl delete pvc -l app.kubernetes.io/name=vault -n vault
```

---

## Troubleshooting: Debugging & Mitigasi

### 1. Error: Permission 'cloudkms.cryptoKeys.get' denied
* **Gejala:** Vault Pod `CrashLoopBackOff` dengan error log:
  ```
  error parsing Seal configuration: error checking key existence: rpc error: code = PermissionDenied desc = Permission 'cloudkms.cryptoKeys.get' denied on resource...
  ```
* **Penyebab:** Google Service Account (`vault-sa`) tidak memiliki role `roles/cloudkms.viewer` untuk memverifikasi detail KMS Key.
* **Mitigasi:**
  Pastikan Terraform/Terragrunt telah meng-apply role `roles/cloudkms.viewer` ke GCP Service Account pada resource KMS key. Jika ingin memitigasi secara instan menggunakan `gcloud`:
  ```bash
  gcloud kms keys add-iam-policy-binding vault-unseal-key \
    --keyring vault-unseal \
    --location asia-southeast1 \
    --member="serviceAccount:vault-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudkms.viewer" \
    --project YOUR_PROJECT_ID
  ```
  Setelah itu, restart pod Vault:
  ```bash
  kubectl delete pod -l app.kubernetes.io/name=vault -n vault
  ```

### 2. Error: 'stored unseal keys are supported, but none were found'
* **Gejala:** Vault berhasil berjalan tetapi statusnya tersegel (`Sealed: true`), dan log menunjukkan:
  ```
  core: stored unseal keys supported, attempting fetch
  failed to unseal core: error="stored unseal keys are supported, but none were found"
  ```
* **Penyebab:** Vault dideploy di cluster baru namun database Raft backend belum di-inisialisasi sama sekali.
* **Mitigasi:**
  Inisialisasi Vault pertama kali secara manual agar auto-unseal key didaftarkan ke KMS key:
  ```bash
  kubectl exec vault-0 -n vault -- vault operator init
  ```
  **Catat dan simpan Recovery Keys & Root Token** yang dihasilkan dari output init tersebut dengan aman.

### 3. Error: 'permission denied' (Code 403) saat menjalankan script init atau seeding
* **Gejala:** Muncul error `permission denied` atau `Code: 403` saat script `vault-init.sh` atau `seed-secrets.sh` mencoba mengakses/mengonfigurasi Vault.
* **Penyebab:** Client Vault di dalam pod `vault-0` belum terotentikasi (belum login dengan Root Token), atau token yang ada telah kadaluarsa.
* **Mitigasi:**
  Kedua script (`vault-init.sh` dan `seed-secrets.sh`) kini otomatis mendeteksi status otentikasi. Jika belum login, script akan meminta Anda memasukkan **Vault Root Token** secara aman di terminal.
  
  Namun, jika Anda ingin melakukan otentikasi/login manual secara langsung di dalam pod `vault-0`, lakukan langkah-langkah berikut:
  1. Periksa status token saat ini di pod:
     ```bash
     kubectl exec -n vault vault-0 -- vault token lookup
     ```
  2. Masuk ke shell pod `vault-0` secara interaktif:
     ```bash
     kubectl exec -it -n vault vault-0 -- sh
     ```
  3. Di dalam shell pod, jalankan perintah login:
     ```bash
     vault login
     ```
  4. Masukkan **Root Token** (atau token administratif Anda) saat diminta. Setelah berhasil login, ketik `exit` untuk keluar dari pod, lalu jalankan kembali script Anda.



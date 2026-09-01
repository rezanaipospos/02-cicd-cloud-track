# Runbook 14: CloudSQL PostgreSQL dengan Private IP & Workload Identity

Dokumen ini berisi panduan langkah demi langkah untuk melakukan provisioning CloudSQL PostgreSQL, mengonfigurasi Private Service Access (peering VPC), menyetel Workload Identity untuk akses database tanpa password, dan melakukan verifikasi koneksi dari pod.

---

## 1. Tahap Provisioning Infrastruktur (Terraform/Terragrunt)

Eksekusi pembaruan VPC (untuk alokasi IP Peering) dan pembuatan database:

```bash
# 1. Update Network VPC untuk mengaktifkan Private Service Access (PSA)
cd 01-infra/environments/dev/network
terragrunt apply

# 2. Deploy CloudSQL Instance + Setup Workload Identity & Database Users
cd 01-infra/environments/dev/cloudsql
terragrunt apply
```

*Catatan: Proses pembuatan instance CloudSQL biasanya memakan waktu sekitar 10-15 menit.*

---

## 2. Tahap Konfigurasi Kubernetes (Workload Identity Annotation)

Setelah Terragrunt selesai dijalankan, Anda harus mengaitkan Kubernetes ServiceAccount (KSA) aplikasi dengan GCP Service Account (GSA) yang baru dibuat menggunakan anotasi khusus.

Jalankan perintah berikut:

```bash
PROJECT_ID="YOUR_PROJECT_ID" # Ganti dengan GCP Project ID Anda

# Anotasikan ServiceAccount backend-go
kubectl annotate sa backend-go -n backend-development \
  iam.gke.io/gcp-service-account=backend-go-db-sa@${PROJECT_ID}.iam.gserviceaccount.com --overwrite

# Anotasikan ServiceAccount backend-go-cinema (jika cinema juga menggunakan IAM)
kubectl annotate sa backend-go-cinema -n backend-development \
  iam.gke.io/gcp-service-account=backend-go-db-sa@${PROJECT_ID}.iam.gserviceaccount.com --overwrite
```

---

## 3. Integrasi Aplikasi & Pengujian Koneksi

### Skenario A: backend-go (Menggunakan Library Google Cloud SQL Connector)
Aplikasi terhubung langsung tanpa sidecar container. Ia mengambil token autentikasi secara otomatis dari lingkungannya.

1. Gunakan library `cloud.google.com/go/cloudsqlconn` di Go.
2. Inisialisasi koneksi dengan opsi `WithIAMAuthN()` seperti contoh pada panduan arsitektur.
3. Aplikasi akan menggunakan DSN format: `user=backend-go-db-sa@PROJECT_ID.iam dbname=coursedb sslmode=disable` (enkripsi SSL dikelola otomatis secara native oleh library).

### Skenario B: backend-go-cinema (Menggunakan Cloud SQL Auth Proxy Sidecar)
Aplikasi terhubung menggunakan connection string Postgres standar dengan username & password tradisional (disimpan di Vault) melalui port lokal `127.0.0.1:5432`.

1. Sidecar proxy (`cloud-sql-proxy`) akan otomatis berjalan di samping pod Anda.
2. Gunakan connection string berikut pada aplikasi cinema Anda:
   ```bash
   APP_DB_URL="postgres://cinema-dev-user:cinema-secure-password@127.0.0.1:5432/coursedb?sslmode=disable"
   ```

---

## 4. Verifikasi Konektivitas Database dari Pod

Untuk memverifikasi koneksi database berjalan dengan baik dari dalam Kubernetes, lakukan langkah berikut:

### Langkah 1: Dapatkan nama pod yang berjalan
```bash
POD_CINEMA=$(kubectl get pods -n backend-development -l app=backend-go-cinema -o jsonpath='{.items[0].metadata.name}')
```

### Langkah 2: Cek log Cloud SQL Auth Proxy sidecar pada pod cinema
Pastikan proxy berhasil mengautentikasi dan mendengarkan koneksi:
```bash
kubectl logs $POD_CINEMA -c cloud-sql-proxy -n backend-development
```
*Log sukses akan menampilkan:*
```text
Authorizing with Application Default Credentials
Listening on 127.0.0.1:5432
The proxy has started successfully and is ready for new connections!
```

### Langkah 3: Tes koneksi port local dari dalam container aplikasi
```bash
kubectl exec -it $POD_CINEMA -c app -n backend-development -- nc -zv 127.0.0.1 5432
```
*Output sukses:*
```text
Connection to 127.0.0.1 5432 port [tcp/postgresql] succeeded!
```

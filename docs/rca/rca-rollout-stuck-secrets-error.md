# Root Cause Analysis (RCA): Backend Go Cinema & Payment Deployment Issues

**Tanggal Kejadian**: 16 Juli 2026  
**Status**: Resolved  
**Dampak**: Pods `backend-go-cinema` dan `backend-go-payment` tidak terbentuk dan status Rollout stuck di `Progressing`.

---

## 1. Kronologi & Deskripsi Masalah

Setelah menambahkan dua microservice internal baru (`backend-go-cinema` dan `backend-go-payment`), deployment tidak berjalan dengan sukses di mana pod tidak terbentuk sama sekali dan replica count bernilai `0 desired / 0 current`. Setelah diinvestigasi, ditemukan dua masalah utama:

### Masalah A: `SecretSyncedError` (403 Permission Denied) pada Vault
* **Gejala**: `ExternalSecret` untuk cinema dan payment gagal disinkronkan.
* **Error Logs**:
  ```
  error retrieving secret at .data[0], key: secret/backend-go-cinema/dev, err: cannot read secret data from Vault: Error making API request. Code: 403. Errors: * 1 error occurred: * permission denied
  ```
* **Akar Masalah**: Konfigurasi path baru di Vault (`secret/data/backend-go-cinema/*` dan `secret/data/backend-go-payment/*`) belum terdaftar di policy Vault (`backend-go`). Sehingga, ServiceAccount tidak diizinkan membaca secret tersebut meskipun otentikasi Kubernetes berhasil.

### Masalah B: Rollout Stuck di `Progressing` (Traffic Routing Error)
* **Gejala**: Rollout stuck dengan pesan `more replicas need to be updated` dan ReplicaSet berstatus `ScaledDown`.
* **Error Logs (Argo Rollouts Controller)**:
  ```
  rollout syncHandler error: failed to remove managed routes via plugin: httproutes.gateway.networking.k8s.io "route" not found
  ```
* **Akar Masalah**: Kedua aplikasi mewarisi konfigurasi `spec.strategy.canary.trafficRouting` (GatewayAPI) dari common template (`../../common/rollout.yaml`). Karena keduanya merupakan service internal dan tidak memiliki resource `HTTPRoute` terdaftar, controller `argo-rollouts` crash saat mencoba merekonsiliasi route tersebut.

---

## 2. Alur Cara Pengecekan & Debugging (Troubleshooting Flow)

Untuk mendiagnosis masalah serupa di masa mendatang, lakukan investigasi secara terstruktur dari tingkat paling atas (Pod/Rollout) hingga ke bawah (Secrets/Vault):

### Langkah 1: Cek Pods & Rollout Status
Pertama, periksa apakah pod sudah berjalan atau belum terbentuk sama sekali:
```bash
# 1. Cek status pods
kubectl get pods -n backend-development

# 2. Cek status Rollout jika pods tidak terbentuk
kubectl get rollout -n backend-development
```
* **Hasil Observasi**: `Desired: 1` tetapi `Current: 0`, dan tidak ada pod baru yang sedang dibuat.

### Langkah 2: Deskripsikan Rollout & Periksa ReplicaSet
Ketika Rollout tidak menskalakan pod baru, periksa status internal object-nya:
```bash
# 1. Deskripsikan Rollout untuk melihat status transisi dan event
kubectl describe rollout backend-go-cinema-rollout -n backend-development

# 2. Periksa status ReplicaSet yang dikendalikan oleh Rollout
kubectl get rs -n backend-development
kubectl describe rs <nama-replicaset-cinema> -n backend-development
```
* **Hasil Observasi**: ReplicaSet berstatus `Replicas: 0 current / 0 desired` dan event kosong. Ini menandakan bahwa **Controller Rollout sengaja tidak menskalakan ReplicaSet** karena ada kegagalan internal pada level controller saat rekonsiliasi.

### Langkah 3: Cek Logs Controller Argo Rollouts
Karena Controller tidak melakukan action scale up tanpa log error di resource Rollout/ReplicaSet, periksa log langsung dari pod controller:
```bash
kubectl logs -n argo-rollouts -l app.kubernetes.io/name=argo-rollouts --tail=100
```
* **Hasil Temuan**: Ditemukan error reconciliation loop: `failed to remove managed routes via plugin: httproutes.gateway.networking.k8s.io "route" not found`. Ini menunjukkan masalah pada konfigurasi **Traffic Routing**.

### Langkah 4: Cek Ketersediaan K8s Secrets & ExternalSecret
Setelah masalah Traffic Routing diperbaiki dan Rollout mencoba scale up, jika pod masih gagal dijadwalkan (misal karena `CreateContainerConfigError` atau ReplicaSet terhambat), verifikasi apakah Kubernetes Secrets yang didefinisikan pada Rollout template (`backend-go-cinema-secrets` & `backend-go-cinema-pem-secrets`) benar-benar ada di cluster:
```bash
# 1. Cek apakah Native K8s Secret sudah terbentuk
kubectl get secret -n backend-development

# 2. Jika tidak ada, cek status ExternalSecret (ESO) yang bertugas men-generate secret tersebut
kubectl get externalsecret -n backend-development
```
* **Hasil Temuan**: Status ExternalSecret menunjukkan `SecretSyncedError` (False).

### Langkah 5: Deskripsikan ExternalSecret untuk Cek Integrasi Vault
Ketika ExternalSecret gagal melakukan sinkronisasi, periksa event dan log detail error integrasinya dengan Vault:
```bash
kubectl describe externalsecret backend-go-cinema-backend-go-secrets -n backend-development
```
* **Hasil Temuan**: Menampilkan error `403 Permission Denied` saat mencoba `GET http://vault.../v1/secret/data/backend-go-cinema/dev`, mengarahkan langsung ke akar masalah pada **Vault Policy / Seeding**.

---

## 3. Solusi & Mitigasi (Mitigation Actions)

### Solusi Jangka Pendek (Resolved)
1. **Pembaruan Policy & Role Vault**:
   * **Deskripsi Perbaikan**:
     * Menambahkan kapabilitas `read` untuk path secret internal cinema dan payment di file policy **[backend-go-policy.hcl](file:///Users/rezanaipospos/Development/be-a-devops-course/course-project/06-secrets-vault/policies/backend-go-policy.hcl)**.
     * Memperbarui script inisialisasi **[vault-init.sh](file:///Users/rezanaipospos/Development/be-a-devops-course/course-project/06-secrets-vault/scripts/vault-init.sh)** agar secara otomatis mendaftarkan ServiceAccount `cinema` dan `payment` (`backend-go-cinema-backend-go`, `backend-go-payment-backend-go`) ke dalam parameter `bound_service_account_names` di role `backend-go-dev`.
   * **Perintah Eksekusi Manual (Ad-hoc Fix)**:
     Untuk menerapkan perbaikan policy langsung ke Vault server yang sedang berjalan di cluster:
     ```bash
     # Menulis ulang policy dengan path baru
     kubectl exec -i -n vault vault-0 -- env VAULT_TOKEN="$VAULT_TOKEN" vault policy write backend-go - <<'EOF'
     path "secret/data/backend-go/*" {
       capabilities = ["read"]
     }
     path "secret/data/backend-go-cinema/*" {
       capabilities = ["read"]
     }
     path "secret/data/backend-go-payment/*" {
       capabilities = ["read"]
     }
     EOF

     # Memperbarui Kubernetes role agar mengizinkan ServiceAccount cinema dan payment
     kubectl exec -i -n vault vault-0 -- env VAULT_TOKEN="$VAULT_TOKEN" vault write auth/kubernetes/role/backend-go-dev \
         bound_service_account_names=backend-go-backend-go,backend-go-cinema-backend-go,backend-go-payment-backend-go \
         bound_service_account_namespaces=backend-development \
         policies=backend-go \
         ttl=1h
     ```
2. **Kustomize Patch untuk Rollout**:
   Menambahkan JSON patch `op: remove` pada `kustomization.yaml` untuk menghapus `/spec/strategy/canary/trafficRouting` pada aplikasi internal yang tidak menggunakan gateway routing.

### Mitigasi Jangka Panjang (Pencegahan)
* **Pemisahan Base Templates**: Bedakan antara base template untuk *External/Public Service* (menggunakan GatewayAPI/HTTPRoute) dan *Internal Service* (tidak menggunakan GatewayAPI) untuk menghindari pewarisan konfigurasi yang tidak perlu.
* **Prosedur Pre-deployment checklist**: Pastikan sebelum mendaftarkan aplikasi baru ke ArgoCD, secret path di Vault sudah di-seed terlebih dahulu beserta pembaharuan policy-nya.

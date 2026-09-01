# Panduan Deploy Service Baru di Ekosistem GitOps

Dokumen ini menjelaskan arsitektur dan komponen yang diperlukan untuk men-deploy service baru (misalnya microservice backend) menggunakan pendekatan GitOps (ArgoCD + Kustomize) di dalam ekosistem ini.

Arsitektur deployment kita menggunakan pola **Base & Overlay** Kustomize, di mana sebagian besar resource standar diwarisi dari template `common` dan dimodifikasi via Kustomize `patches` dan `replacements`.

---

## 1. Komponen Wajib (Required Components)

Saat membuat service baru, Anda akan membuat direktori overlay baru (misal: `applications/development/service-baru/`). Hampir semua komponen ini di-generate dari `../../common` atau didefinisikan di overlay:

### A. Argo Rollout (Pengganti Deployment)
* **Fungsi**: Mengelola siklus hidup Pod, strategi deployment (Canary/Blue-Green), dan integrasi dengan ingress/gateway.
* **Konfigurasi**: Diturunkan dari `common/rollout.yaml`. Di overlay, kita melakukan patching (via `kustomization.yaml` atau `patch/rollout.yaml`) untuk mengubah image, resources, env vars, dan konfigurasi volume (secrets).

### B. ServiceAccount
* **Fungsi**: Memberikan identitas unik pada Pod. Sangat penting untuk integrasi otentikasi dengan HashiCorp Vault (via Kubernetes Auth Method).
* **Konfigurasi**: Diturunkan dari `common`. Nama ServiceAccount otomatis di-prefix oleh Kustomize.

### C. Kubernetes Service
* **Fungsi**: Endpoint internal K8s untuk Load Balancing traffic ke Pods yang dikelola oleh Rollout. Argo Rollouts biasanya menggunakan dua service untuk Canary (Stable & Canary service).
* **Konfigurasi**: Diturunkan dari `common`. Selector otomatis di-update via Kustomize patch agar sesuai dengan Rollout.

### D. SecretStore & ExternalSecret (ESO)
* **Fungsi**: Mengambil secret secara aman dari HashiCorp Vault dan menyinkronkannya ke native Kubernetes `Secret`.
* **Konfigurasi**: Didefinisikan di file `secrets.yaml` pada direktori service. `ExternalSecret` merujuk ke path Vault spesifik (misal: `secret/service-baru/dev`), lalu men-generate K8s Secret yang di-mount oleh Rollout (sebagai `envFrom` atau `volume`).

### E. HorizontalPodAutoscaler (HPA) & PodDisruptionBudget (PDB)
* **Fungsi**: HPA mengatur auto-scaling (jumlah replica) berdasarkan load CPU/Memory. PDB memastikan ketersediaan minimum pod selama proses maintenance/eviction (node drain).
* **Konfigurasi**: HPA diturunkan dari `common`. Pada environment non-production (dev), PDB biasanya di-patch untuk menghapus `minAvailable` agar tidak memblokir eviction.

### F. NetworkPolicy
* **Fungsi**: Mengamankan komunikasi antar-pod di dalam cluster (Zero Trust network).
* **Konfigurasi**: Didefinisikan di `network-policy.yaml`. Mengatur ingress/egress, memblokir akses secara default (default deny), dan hanya membuka port yang diperlukan dari sumber spesifik.

---

## 2. Cara Expose Service (External vs Internal)

Sistem ini mendukung dua mode deployment: diekspos ke publik menggunakan **Envoy Gateway (Gateway API)** atau dibiarkan sebagai service **Internal**. Kunci perbedaannya ada pada konfigurasi `HTTPRoute` dan fitur `trafficRouting` di Argo Rollouts.

### Skenario A: Expose via Envoy Gateway (Public / External)
Cocok untuk service yang perlu diakses dari luar cluster (misal: frontend web, public API gateway).

1. **HTTPRoute Component**:
   * Didefinisikan di file `network/http-route.yaml`.
   * Komponen Gateway API ini mengonfigurasi Envoy untuk merutekan traffic dari hostname/path tertentu ke Kubernetes Service milik aplikasi.
2. **Kustomization resources**:
   * Harus menyertakan `- network/http-route.yaml` di array `resources`.
3. **Rollout Canary Traffic Routing**:
   * Pada `common/rollout.yaml`, `trafficRouting` diset default menggunakan plugin `argoproj-labs/gatewayAPI` yang mencari object `HTTPRoute`.
   * Saat `HTTPRoute` didefinisikan dan Kustomize `replacements` mengeksekusi wiring namanya, Argo Rollouts akan mengontrol persentase traffic (canary steps) langsung di level Envoy Gateway.

### Skenario B: Tanpa Envoy Gateway (Internal Service)
Cocok untuk microservice yang hanya diakses oleh service lain di dalam cluster (misal: `backend-go-cinema`, `backend-go-payment`).

1. **Tanpa HTTPRoute**:
   * Jangan membuat atau menyertakan file `http-route.yaml`.
2. **Hapus TrafficRouting dari Rollout (WAJIB)**:
   * Karena service internal mewarisi `common/rollout.yaml` (yang memiliki konfigurasi GatewayAPI), controller Argo Rollouts akan error/stuck jika tidak menemukan `HTTPRoute`.
   * **Mitigasi**: Hapus blok `trafficRouting` menggunakan JSON Patch di `kustomization.yaml` milik service internal tersebut:
     ```yaml
     patches:
     - patch: |
         - op: remove
           path: /spec/strategy/canary/trafficRouting
       target:
         kind: Rollout
         name: rollout
     ```
   * Dengan penghapusan ini, Argo Rollouts akan mundur (fallback) menggunakan **basic replica-based canary scaling** (hanya mengatur jumlah pod lama vs baru) tanpa integrasi traffic ingress spesifik.
3. **Akses via Kubernetes DNS**:
   * Service lain memanggil service ini menggunakan FQDN Kubernetes internal: `http://<nama-service>.<namespace>.svc.cluster.local:<port>`.

## 3. Parameter & Nilai yang Harus Disesuaikan (Values Customization)

Saat membuat service baru dengan menduplikasi template/overlay yang ada, pastikan Anda menyesuaikan value-value berikut agar tidak terjadi konflik nama atau kesalahan routing:

### A. Di File `kustomization.yaml`
* **`namePrefix`**: Tentukan nama prefix unik untuk service tersebut (contoh: `backend-go-cinema-`). Kustomize akan otomatis menambahkan prefix ini di depan semua nama resource (Service, ServiceAccount, Rollout, dll).
* **`labels`**: Sesuaikan metadata label untuk keperluan monitoring dan klasifikasi:
  ```yaml
  labels:
  - pairs:
      service_name: backend-go-cinema # Nama service baru
      app: backend-go-cinema          # Label selektor utama
  ```
* **`patches` (Replace App Selectors)**: Ganti nilai `value` pada patch JSON replace agar sesuai dengan label aplikasi baru:
  * `/spec/selector/matchLabels/app` ➜ `backend-go-cinema`
  * `/spec/template/metadata/labels/app` ➜ `backend-go-cinema`
  * `/spec/selector/app` (pada target Service) ➜ `backend-go-cinema`

### B. Di File `patch/rollout.yaml`
* **`image`**: Masukkan URL image Artifact Registry (atau Docker registry lainnya) yang sesuai dengan service baru Anda:
  ```yaml
  image: asia-southeast1-docker.pkg.dev/<PROJECT_ID>/<REPO>/service-baru:tag
  ```
* **`envFrom.secretRef.name`**: Sesuaikan dengan nama Secret yang akan di-consume oleh pod Anda (contoh: `backend-go-cinema-secrets`).
* **`volumes.secret.secretName`**: Jika menggunakan volume secret (seperti file `.pem`), sesuaikan nama target secretnya (contoh: `backend-go-cinema-pem-secrets`).

### C. Di File `secrets.yaml`
* **`ExternalSecret.metadata.name`**: Nama resource ExternalSecret (contoh: `backend-go-secrets`).
* **`ExternalSecret.spec.target.name`**: Nama Kubernetes Secret hasil generate yang akan dicari oleh Rollout (contoh: `backend-go-cinema-secrets`).
* **`ExternalSecret.spec.data[].remoteRef.key`**: Path KV Engine v2 di Vault tempat Anda menyimpan secret aplikasi tersebut (contoh: `secret/backend-go-cinema/dev`).

### D. Di File `network-policy.yaml`
* **`spec.podSelector.matchLabels.app`**: Label aplikasi target yang akan dilindungi oleh policy ini (contoh: `backend-go-cinema`).
* **`spec.ingress.from.podSelector.matchLabels.app`**: Tentukan aplikasi mana saja yang diizinkan memanggil service ini (contoh: `backend-go` untuk memperbolehkan gateway internal memanggil API cinema).

### E. Di File `network/http-route.yaml` (Hanya jika Skenario External)
* **`spec.hostnames`**: Domain atau routing path luar yang dialokasikan (contoh: `cinema.devops-course.my.id`).
* **`spec.rules.backendRefs.name`**: Nama Kubernetes Service target (contoh: `backend-go-cinema-svc`).

---

## 4. Checklist Langkah Deployment Service Baru

1. **Buat Direktori Overlay**: Kopi template Kustomize (dari service sejenis) ke folder baru (misal: `applications/development/service-baru`).
2. **Sesuaikan Nama & Label**: Update `namePrefix` dan label selector di `kustomization.yaml`.
3. **Sesuaikan Vault Path & Auth**: 
   * Update `secrets.yaml` untuk menunjuk ke path secret yang benar.
   * Update `vault-init.sh` dan policy HCL untuk memberikan izin akses (policy) & meregistrasikan ServiceAccount ke role Vault.
   * Jalankan script seeding rahasia (seperti `seed-secrets.sh`).
4. **Pilih Mode Eksposure**: 
   * Jika External: Konfigurasi `http-route.yaml`.
   * Jika Internal: Hapus `trafficRouting` via Kustomize patch.
5. **Sesuaikan NetworkPolicy**: Buat rule Ingress spesifik (siapa yang boleh memanggil service ini).
6. **Daftarkan di ArgoCD**: Tambahkan manifest aplikasi baru di folder `bootstrap/apps/` agar otomatis disinkronisasi.

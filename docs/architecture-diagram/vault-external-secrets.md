# Sequence Diagram: Vault & External Secrets

Diagram *Sequence* berikut menggambarkan **urutan kronologis** dari awal penerapan konfigurasi (deploy) hingga bagaimana Pod aplikasi akhirnya mendapatkan rahasia tersebut.

```mermaid
sequenceDiagram
    autonumber
    
    actor DevOps as DevOps Engineer
    participant K8s as Kubernetes API
    participant ESO as External Secrets Operator
    participant Vault as HashiCorp Vault
    participant Pod as Backend Go Pod

    Note over DevOps, Pod: FASE 1: Penerapan Konfigurasi (GitOps / Kustomize)
    DevOps->>K8s: Deploy ServiceAccount (backend-go)
    DevOps->>K8s: Deploy SecretStore (definisi cara konek & auth ke Vault)
    DevOps->>K8s: Deploy ExternalSecret (permintaan mengambil spesifik secret dari Vault)
    DevOps->>K8s: Deploy Rollout (manifest Pod aplikasi backend)

    Note over K8s, Vault: FASE 2: Sinkronisasi dan Autentikasi (ESO & Vault)
    ESO->>K8s: Mendeteksi adanya ExternalSecret baru
    ESO->>K8s: Membaca referensi SecretStore (diminta menggunakan SA backend-go)
    
    ESO->>K8s: Meminta JWT Token (Workload Identity) atas nama SA backend-go
    K8s-->>ESO: Mengembalikan JWT Token yang ditandatangani
    
    ESO->>Vault: Melakukan Login (Kubernetes Auth) dengan mengirim JWT Token
    Vault->>K8s: TokenReview API: Memvalidasi apakah JWT Token ini sah?
    K8s-->>Vault: Ya, Token Valid dan milik ServiceAccount "backend-go" di namespace dev
    
    Vault-->>ESO: Akses Diberikan. Mengembalikan "Vault Access Token"
    
    ESO->>Vault: Mengambil data aktual (Fetch) dari Vault KV (contoh: APP_DB_PASSWORD)
    Vault-->>ESO: Mengirimkan data rahasia tersebut
    
    Note over ESO, K8s: FASE 3: Materialisasi Secret K8s Asli
    ESO->>K8s: Membuat resource "Kubernetes Secret" standar (berisi base64 data dari Vault)
    
    Note over K8s, Pod: FASE 4: Konsumsi Rahasia oleh Aplikasi
    K8s->>Pod: Mulai membuat container (Kubelet memproses Pod spec)
    K8s-->>Pod: Kubelet memuat (inject) K8s Secret sebagai Environment Variable (envFrom)
    K8s-->>Pod: Kubelet me-mount (inject) K8s Secret sebagai file (volumeMounts untuk sertifikat.pem)
    
    Pod->>Pod: Aplikasi Backend-Go berjalan dengan rahasia aman di dalam memorinya!
```

### Penjelasan Urutan Kejadian:

1. **Fase 1 (Langkah 1-4)**: Semua manifest di-*deploy* ke klaster. Kunci utamanya adalah kita membuat `ServiceAccount`, `SecretStore`, dan `ExternalSecret`. Manifest aplikasi (Rollout) mengarahkan Pod-nya agar me-load variabel menggunakan nama K8s Secret (meskipun wujud secret-nya belum ada di klaster).
2. **Fase 2 (Langkah 5-12)**: Inilah otak pergerakannya. `External Secrets Operator` akan bertindak sebagai agen/kurir yang secara otomatis bekerja. 
   - Supaya agen ini bisa membuktikan identitasnya ke Vault, ia meminta **token K8s JWT** dari ServiceAccount `backend-go` dan memberikannya ke Vault. 
   - Vault tidak langsung percaya, ia memvalidasi lagi token tersebut ke K8s API (TokenReview). 
   - Setelah yakin token itu asli, Vault mengizinkan ESO untuk membaca nilai rahasia (contoh: *Database Password*).
3. **Fase 3 (Langkah 13)**: ESO mengambil semua rahasia yang ia dapatkan dari Vault tadi, kemudian menuliskannya ke dalam wujud **Kubernetes Secret biasa** (berbentuk base64).
4. **Fase 4 (Langkah 14-17)**: Saat Kubelet menyalakan Pod `backend-go`, Pod tersebut akan otomatis memuat (load) Kubernetes Secret (hasil karya ESO di langkah 13) ke dalam Environment Variable (`envFrom`) atau menyimpannya sebagai file (`volumeMounts`).

Dengan cara ini, pengembang (Anda) hanya menaruh rahasia di dalam Vault. Di dalam Kubernetes tidak ada file `.yaml` yang menyimpan teks asli password Anda. Semuanya ditarik secara dinamis pada saat *runtime*.

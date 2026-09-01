# Vault & External Secrets Architecture Diagram

Berikut adalah visualisasi interkoneksi komponen dalam bentuk text-art (ASCII) untuk menjelaskan relasi referensi parameter (`yaml` key) serta alur pengisian rahasia dari HashiCorp Vault ke Kubernetes Workload Pod, termasuk peran **GCP Cloud KMS** dalam proses **Vault Auto-Unseal**.

Baca nomor urut (1 → 7) untuk mengikuti alur kejadian secara kronologis.

```text
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  GOOGLE CLOUD PLATFORM (GCP)                                                        │
│                                                                                     │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │  GCP Cloud KMS (Key Management Service)                                      │  │
│  │  Key Ring : vault-unseal                                                     │  │
│  │  Key      : vault-unseal-key                                                 │  │
│  │  ──────────────────────────────────────────────────────────────────────────  │  │
│  │  Mengenkripsi/Dekripsi Vault Master Key untuk Auto-Unseal                    │  │
│  └────────────────▲─────────────────────────────────────────────────────────────┘  │
│                   │                                                                 │
│                   │ 1. Vault mengirim Master Key ke KMS untuk di-Encrypt/Decrypt    │
│                   │    (GCP IAM: roles/cloudkms.cryptoKeyEncrypterDecrypter)        │
└───────────────────┼─────────────────────────────────────────────────────────────────┘
                    │
                    │ 2. KMS mengembalikan kunci terenkripsi → Vault status: Unsealed
                    ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  HASHICORP VAULT (External Secret Store)                                            │
│                                                                                     │
│  Status: Auto-Unsealed (Aktif otomatis berkat GCP KMS)                              │
│  KV Path: secret/backend-go/dev                                                     │
│  ┌────────────────────────────────────────────────────┐                             │
│  │  Key/Value data:                                   │                             │
│  │    - APP_DB_PASSWORD : "reza-devops"               │                             │
│  │    - APP_DB_URL      : "postgresql://..."          │                             │
│  └────────────────────────────────────────────────────┘                             │
│                           ▲                                                         │
│                           │ 6. Vault mengembalikan nilai rahasia ke ESO             │
│                           │                                                         │
│                           │ 5. ESO mengambil secret menggunakan Vault Token         │
│                           │                                                         │
└───────────────────────────┼─────────────────────────────────────────────────────────┘
                            │
                            │ 4. Vault memvalidasi JWT ke K8s TokenReview API,
                            │    lalu mengembalikan Vault Access Token ke ESO
                            ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  KUBERNETES CLUSTER (Namespace: backend-development)                                │
│                                                                                     │
│  ┌───────────────────────────────────────────────────────────────────────────────┐  │
│  │  ServiceAccount: backend-go-backend-go                                        │  │
│  │  ───────────────────────────────────────────────────────────────────────────  │  │
│  │  Menyediakan JWT Token (K8s Workload Identity) untuk login ke Vault           │  │
│  └────────────────▲──────────────────────────────────────────▲───────────────────┘  │
│                   │                                          │                      │
│                   │ 3a. SecretStore membaca JWT Token        │ 3b. Pod berjalan     │
│                   │     dari ServiceAccount ini              │     sebagai SA ini   │
│                   │                                          │                      │
│  ┌────────────────┴────────────────────────┐      ┌──────────┴────────────────────┐  │
│  │  SecretStore: backend-go-vault-backend  │      │  Rollout: backend-go-rollout  │  │
│  │  ─────────────────────────────────────  │      │  ───────────────────────────  │  │
│  │  spec:                                  │      │  spec:                        │  │
│  │    provider:                            │      │    template:                  │  │
│  │      vault:                             │      │      spec:                    │  │
│  │        auth:                            │      │        serviceAccountName:    │  │
│  │          kubernetes:                    │      │          backend-go-backend-go│  │
│  │            role: backend-go-dev  ───────┼──►Vault menentukan akses            │  │
│  │            serviceAccountRef:           │      │        containers:            │  │
│  │              name: backend-go-backend-go│      │        - name: app            │  │
│  └─────────────────▲───────────────────────┘      │          envFrom:             │  │
│                    │                              │          - secretRef:         │  │
│                    │ 3. ESO membaca konfigurasi   │              name:            │  │
│                    │    auth dari SecretStore ini  │              backend-go-      │  │
│                    │                              │              secrets  ◄───┐   │  │
│  ┌─────────────────┴───────────────────────┐      └───────────────────────────┼───┘  │
│  │  ExternalSecret: backend-go-secrets     │                                  │      │
│  │  ─────────────────────────────────────  │                                  │      │
│  │  spec:                                  │                                  │      │
│  │    secretStoreRef:                      │                                  │      │
│  │      name: backend-go-vault-backend ◄───┼─── referensi ke SecretStore      │      │
│  │    target:                              │                                  │      │
│  │      name: backend-go-secrets  ─────────┼──────────────────────────────────┘      │
│  │    data:                                │   7b. Pod memuat Secret ini             │
│  │    - secretKey: APP_DB_PASSWORD         │       sebagai Environment Variable      │
│  │      remoteRef:                         │                                         │
│  │        key: secret/backend-go/dev       │                                         │
│  │        property: APP_DB_PASSWORD        │                                         │
│  └─────────────────▲───────────────────────┘                                         │
│                    │                                                                  │
│                    │ 2. ESO mendeteksi ExternalSecret ini dan memulai reconciliation  │
│                    │                                                                  │
│  ┌─────────────────┴───────────────────────┐      ┌───────────────────────────┐      │
│  │  External Secrets Operator (ESO)        │      │  Kubernetes Secret        │      │
│  │  ─────────────────────────────────────  │      │  backend-go-secrets       │      │
│  │  Namespace: external-secrets            │      │  ───────────────────────  │      │
│  │  - Watch ExternalSecret & SecretStore   │ 7a.  │  data:                    │      │
│  │  - Ambil JWT SA → Tukar ke Vault Token  ├─────►│    APP_DB_PASSWORD:       │      │
│  │  - Fetch Secret dari Vault → Write K8s  │ Buat │      cmV6YS1kZXZvcHM=    │      │
│  └─────────────────────────────────────────┘      └───────────────────────────┘      │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Urutan Langkah (Baca dari nomor 1):

| # | Aktor | Aksi |
|---|-------|------|
| **1** | **Vault → GCP KMS** | Vault mengirimkan Master Key terenkripsi ke GCP KMS saat startup untuk proses Auto-Unseal |
| **2** | **GCP KMS → Vault** | KMS mendekripsi dan mengembalikan kunci, Vault berhasil masuk status *Unsealed* (aktif) |
| **3** | **ESO → ExternalSecret → SecretStore** | ESO mendeteksi resource ExternalSecret baru, membaca konfigurasi autentikasi dari SecretStore |
| **3a** | **SecretStore → ServiceAccount** | SecretStore mereferensikan ServiceAccount `backend-go-backend-go` untuk diambil JWT Token-nya |
| **3b** | **Rollout → ServiceAccount** | Pod Rollout dijalankan menggunakan identitas ServiceAccount `backend-go-backend-go` |
| **4** | **ESO → Vault (Auth)** | ESO mengirim JWT Token SA ke Vault (Kubernetes Auth). Vault memvalidasi ke K8s TokenReview API, lalu mengembalikan *Vault Access Token* |
| **5** | **ESO → Vault (Fetch)** | ESO menggunakan Vault Token untuk membaca nilai rahasia dari path `secret/backend-go/dev` |
| **6** | **Vault → ESO** | Vault mengembalikan nilai rahasia (`APP_DB_PASSWORD`, dll.) ke ESO |
| **7a** | **ESO → K8s Secret** | ESO menulis (materialisasi) semua nilai rahasia tersebut ke dalam Kubernetes Secret `backend-go-secrets` |
| **7b** | **Pod → K8s Secret** | Kubelet me-inject Kubernetes Secret ke dalam kontainer Pod sebagai Environment Variable (`envFrom`) |

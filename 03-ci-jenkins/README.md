# 03 — CI: Jenkins + Shared Library

**Prereq:** 02-config-mgmt (Jenkins berjalan).

## Tujuan
Pipeline CI reusable via **Jenkins Shared Library**. Logika pipeline terpusat; tiap app cukup `Jenkinsfile` tipis + `.cicd/pipeline.yaml`.

## Model CI (keputusan arsitektur)
- **Multibranch Pipeline per app** (AD-11): tiap branch (development/staging/production) = sub-job dengan history & build number sendiri → kejelasan "latest prod build".
- **RBAC** (akses prod hanya lead): plugin Role-Based Authorization Strategy, project role regex `.*/production` → lead; `.*/(development|staging)` → developer. Deploy prod digerbang `input submitter`.
- **Trigger** (AD-12): webhook GitHub setelah human merge (bukan auto-merge).
- **Build** (AD-13): Kaniko (rootless). **Tag** (AD-14): git short SHA, build-once-promote.
- **Config** (AD-15): `.cicd/pipeline.yaml` di repo app.
- **Agent** (AD-16): mulai di VM Jenkins; migrasi K8s agent setelah Epic 4.

## Struktur shared library

```
shared-library/
├── vars/
│   ├── containerPipeline.groovy   # entry point: containerPipeline()
│   ├── buildAndPush.groovy        # Kaniko build+push, tag SHA
│   ├── updateGitops.groovy        # update kustomization image tag + push (lock)
│   ├── notifySlack.groovy         # notifikasi Slack threaded
│   └── trivyScan.groovy           # [NEW] Scanner Trivy (FS/Secrets & Image)
├── src/com/course/
│   └── PipelineConfig.groovy      # load + validasi .cicd/pipeline.yaml
└── examples/
    ├── pipeline.yaml              # contoh .cicd/pipeline.yaml (di repo app)
    └── Jenkinsfile                # contoh Jenkinsfile (di repo app)
```

## Fitur DevSecOps (Trivy Security Scanning)
Pipeline secara default akan melakukan pemindaian keamanan menggunakan **Trivy** pada dua tahap:
1. **Source Code / Filesystem (`type: 'fs'`)**: Memindai kerentanan library (SCA), miskonfigurasi IaC, dan kebocoran *secret* (`--scanners vuln,secret,config`).
2. **Container Image (`type: 'image'`)**: Memindai OS-level vulnerability pada image docker sebelum di-push ke registry.

> [!IMPORTANT]
> Pipeline akan **gagal otomatis (exit-code 1)** jika terdeteksi celah keamanan dengan tingkat keparahan **HIGH** atau **CRITICAL**.


## Registrasi di Jenkins
1. **Manage Jenkins → System → Global Pipeline Libraries**
   - Name: `course-shared-library`
   - Default version: `main` (atau branch/tag)
   - Retrieval method: Modern SCM → Git → URL repo shared library ini.
2. **Buat Multibranch Pipeline** per app:
   - Branch Sources → GitHub → pilih repo app.
   - Build Configuration: by Jenkinsfile (root).
3. **Webhook**: GitHub repo → Settings → Webhooks → `https://<jenkins>/github-webhook/`.

## Cara pakai (di repo app)
- Tambah `.cicd/pipeline.yaml` (lihat `examples/pipeline.yaml`).
- Tambah `Jenkinsfile` (lihat `examples/Jenkinsfile`).

## Kredensial yang dibutuhkan (Jenkins Credentials)
- `github-jenkins-token` — token GitHub (checkout + push GitOps).
- Akses Artifact Registry via Workload Identity / `docker-credential-gcr` di agent.
- Slack token (plugin Slack Notification).

## Catatan kurasi (dari shared library produksi)
Diperbaiki: config 27 env-var → YAML; auto-merge dihapus (human merge); DinD → Kaniko; tag BUILD_NUMBER → git SHA. Dipertahankan: `lock('gitops')`, kustomize `images[].newTag`, Slack threaded.

# Runbook — Perintah Apply per Stage

Dokumen ini adalah indeks panduan langkah-demi-langkah per stage untuk membangun platform end-to-end. Untuk memudahkan navigasi dan pemeliharaan, panduan lengkap telah dipecah ke file-file terpisah di folder `runbooks/`.

## Indeks Panduan Runbook

Silakan ikuti panduan berikut sesuai urutan stage:

| Stage / Topik | Panduan Runbook | Deskripsi |
|---------------|-----------------|-----------|
| **Prasyarat** | [00-Prerequisites](runbooks/00-prerequisites.md) | Konfigurasi IAM roles, GCP login, dan install local tools. |
| **Stage 00** | [01-Bootstrap](runbooks/01-bootstrap.md) | Bootstrap Terraform GCS state bucket, enable API, dan SA Impersonation. |
| **Stage 01** | [02-Infra](runbooks/02-infra.md) | Provisioning Network, Compute (VM Jenkins), dan Artifact Registry via Terragrunt. |
| **SSL** | [03-SSL Let's Encrypt](runbooks/03-ssl.md) | Generate wildcard SSL Let's Encrypt untuk VM Jenkins dan Kubernetes Secret. |
| **Stage 02** | [04-Config Management](runbooks/04-config-mgmt.md) | Konfigurasi Ansible untuk install Jenkins + HAProxy, setup JCasC, dan credentials. |
| **Stage 02b** | [05-Jenkins Plugins](runbooks/05-jenkins-plugins.md) | Daftar plugin Jenkins wajib dan konfigurasi post-install (Slack, Go, Lockable Resources). |
| **Stage 03** | [06-CI Pipeline](runbooks/06-ci-pipeline.md) | Setup Job CI Pipeline, Shared Library, dan GitHub Webhook (HMAC secure). |
| **Stage 04** | [07-GKE](runbooks/07-gke.md) | Provisioning GKE cluster private + Workload Identity via Terragrunt. |
| **Stage 05** | [08-GitOps](runbooks/08-gitops.md) | Install ArgoCD, connect ke private GitHub repo, dan deploy app-of-apps. |
| **Stage 05b** | [09-Envoy Gateway](runbooks/09-envoy-gateway.md) | Install Envoy Gateway dan expose ArgoCD UI + backend-go-dev via HTTPS. |
| **Stage 05c** | [10-Progressive Delivery](runbooks/10-progressive-delivery.md) | Install Argo Rollouts, setup Gateway API plugin, dan monitor canary steps. |
| **Teardown** | [11-Teardown](runbooks/11-teardown.md) | Prosedur hapus infrastruktur (destroy protection) dan estimasi biaya. |
| **Promotion** | [12-Promotion Pattern](runbooks/12-promotion-pattern.md) | Alur promosi image "build once, promote many" dan simulasi manual. |
| **Stage 06** | [13-Vault Secrets](runbooks/13-vault-secrets.md) | Mengelola secrets dengan HashiCorp Vault dan External Secrets Operator. |
| **Stage 07** | [14-New Relic Observability](runbooks/14-newrelic-observability.md) | Instrumentasi Go Agent (5 jenis) + Argo Rollouts canary 3-stage metric-gated NR. |

---
> **Aturan Repo (Invariant):**
> - Nilai lingkungan (project_id, region, domain) selalu via file variabel + `*.example`; tidak hardcoded.
> - Terraform state di GCS backend; `*.tfstate*` tidak di-commit.
> - Tiap stage cloud punya `teardown.sh` + catatan biaya.
> - Tidak ada secret plaintext di repo.
> - Panduan kanonik ada di `docs/`.

# Be A DevOps Employee — Project Repo

Platform DevOps production-grade end-to-end (Cloud track / GCP). Disusun sebagai *numbered-stage monorepo*: ikuti folder berurutan nomor. Setiap stage hanya bergantung pada output stage bernomor lebih kecil.

## Prasyarat
- Akun & billing GCP sendiri (lihat `onboarding/`).
- Tool dasar terpasang (lihat `onboarding/`).

## Urutan Stage
| Stage | Folder | Fokus |
|-------|--------|-------|
| Onboarding | `onboarding/` | Linux, Git, Docker, akun GCP |
| 00 | `00-bootstrap/` | GCS backend state, enable API, IAM dasar |
| 01 | `01-infra/` | Jaringan + VM Jenkins (Terraform/Terragrunt) |
| 02 | `02-config-mgmt/` | Ansible: install & harden Jenkins |
| 03 | `03-ci-jenkins/` | Jenkins CI + shared library (contoh Go) |
| 04 | `04-gke/` | Provisioning GKE |
| 05 | `05-gitops/` | ArgoCD app-of-apps + Kustomize |
| 06 | `06-progressive-delivery/` | Argo Rollouts (canary) |
| 07 | `07-secrets-vault/` | Vault secret management |
| 08 | `08-sso-keycloak/` | Keycloak SSO |
| 09 | `09-gateway-envoy/` | Envoy Gateway |
| 10 | `10-observability/` | New Relic + golden-signal alert (Terragrunt) |
| 11 | `11-capstone/` | Alur penuh end-to-end + teardown |

## Aturan Repo (invariant)
- Nilai lingkungan (project_id, region, domain) selalu via file variabel + `*.example`; tidak hardcoded.
- Terraform state di GCS backend; `*.tfstate*` tidak di-commit.
- Tiap stage cloud punya `teardown.sh` + catatan biaya.
- Tidak ada secret plaintext di repo.
- Panduan kanonik ada di `docs/`.

> Detail invariant lengkap: lihat architecture spine di `_bmad-output/planning-artifacts/architecture/`.

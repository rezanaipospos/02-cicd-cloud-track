# Runbook Index

Runbook dipecah per stage untuk kemudahan navigasi.

| File | Stage | Deskripsi |
|------|-------|-----------|
| [00-prerequisites.md](00-prerequisites.md) | Prasyarat | IAM roles, tooling |
| [01-bootstrap.md](01-bootstrap.md) | Stage 00 | Terraform bootstrap, GCS state |
| [02-infra.md](02-infra.md) | Stage 01 | Network, Compute, Artifact Registry |
| [03-ssl.md](03-ssl.md) | SSL | Let's Encrypt wildcard — VM + Kubernetes |
| [04-config-mgmt.md](04-config-mgmt.md) | Stage 02 | Ansible, Jenkins install |
| [05-jenkins-plugins.md](05-jenkins-plugins.md) | Stage 02b | Plugin Jenkins wajib |
| [06-ci-pipeline.md](06-ci-pipeline.md) | Stage 03 | CI Pipeline, Shared Library, Webhook |
| [07-gke.md](07-gke.md) | Stage 04 | GKE cluster |
| [08-gitops.md](08-gitops.md) | Stage 05 | ArgoCD, app-of-apps, GitOps |
| [09-envoy-gateway.md](09-envoy-gateway.md) | Stage 05b | Envoy Gateway, expose domain |
| [10-progressive-delivery.md](10-progressive-delivery.md) | Stage 05c | Argo Rollouts, canary |
| [11-teardown.md](11-teardown.md) | Teardown | Destroy protection & teardown |
| [12-promotion-pattern.md](12-promotion-pattern.md) | Promotion | Kustomize promotion & progressive delivery details |
| [13-vault-secrets.md](13-vault-secrets.md) | Stage 06 | Secret Management: Vault & External Secrets Operator |
| [14-cloudsql-iam-auth.md](14-cloudsql-iam-auth.md) | Stage 07 | Database: CloudSQL PostgreSQL dengan Private IP & Workload Identity |

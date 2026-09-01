# Automation Scripts — Be A DevOps Engineer (GCP Cloud Track)

Koleksi script otomatisasi instalasi tools & dependensi lab GCP Cloud Track:

| Script | Target OS / Arsitektur | Keterangan |
|---|---|---|
| `install-mac-as.sh` | macOS (Apple Silicon M1/M2/M3/M4 & Intel) | Install Homebrew, Google Cloud SDK, GKE Auth Plugin, Terraform, Terragrunt, kubectl, Helm, Kustomize, Ansible, ArgoCD CLI, & Argo Rollouts Plugin. |
| `install-linux.sh` | Ubuntu / Debian / Windows WSL2 (amd64 & arm64) | Setup apt repo resmi Google Cloud & HashiCorp, install gcloud, terraform, terragrunt, kubectl, helm, kustomize, ansible, argocd, & kubectl-argo-rollouts. |

## Cara Menjalankan

### macOS:
```bash
chmod +x ./scripts/install-mac-as.sh
./scripts/install-mac-as.sh
```

### Linux / WSL2:
```bash
chmod +x ./scripts/install-linux.sh
./scripts/install-linux.sh
```

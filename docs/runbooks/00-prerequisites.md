# Prasyarat & IAM Roles

**Tujuan:** Pastikan akun GCP dan tooling siap sebelum menjalankan stage manapun.

---

## IAM Roles untuk User Account

### Role yang WAJIB dimiliki

| Role | Alasan |
|------|--------|
| `roles/owner` | Paling mudah untuk lab/course |
| ATAU kombinasi: | |
| `roles/iam.serviceAccountAdmin` | Membuat SA Terraform |
| `roles/iam.serviceAccountTokenCreator` | Impersonate SA |
| `roles/storage.admin` | Membuat bucket state |
| `roles/serviceusage.serviceUsageAdmin` | Enable API |
| `roles/resourcemanager.projectIamAdmin` | Memberi role ke SA |
| `roles/compute.admin` | Membuat VPC, VM |

```bash
PROJECT_ID="your-project-id"
USER_EMAIL="kamu@gmail.com"

# Set owner role (paling simpel untuk lab)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/owner"
```

---

## Tools yang Harus Terpasang

| Tool | Versi | Install |
|------|-------|---------|
| `gcloud` | latest | https://cloud.google.com/sdk/install |
| `terraform` | >= 1.3 | https://developer.hashicorp.com/terraform/install |
| `terragrunt` | >= 0.50 | https://terragrunt.gruntwork.io/docs/getting-started/install |
| `kubectl` | latest | `gcloud components install kubectl` |
| `helm` | >= 3.10 | https://helm.sh/docs/intro/install |
| `kustomize` | >= 5.0 | `brew install kustomize` |
| `ansible` | >= 2.14 | `pip install ansible` |
| `argocd` CLI | latest | `brew install argocd` |
| `kubectl argo rollouts` | latest | https://argoproj.github.io/argo-rollouts/installation |

---

## Login GCP

```bash
# Login user account
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Application Default Credentials (untuk Terraform)
gcloud auth application-default login

# Verifikasi
gcloud config list
gcloud auth list
```

---

## Verifikasi IAM

```bash
# Cek role user
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:$USER_EMAIL" \
  --format="table(bindings.role)"
```

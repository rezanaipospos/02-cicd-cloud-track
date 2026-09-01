# Argo Rollouts Install

Versi: **v1.9.0** (latest stable, 2025)

File manifest `argo-rollouts-controller-install.yaml` di-commit lokal ke repo (bukan remote URL).
ArgoCD manage file ini via infrastructure Application → auto-sync ke namespace `argo-rollouts`.

## Kenapa file lokal, bukan remote URL?

- **Reproducible offline** — tidak butuh koneksi internet saat ArgoCD sync
- **Dapat di-patch** — tambah ConfigMap, RBAC, atau override tanpa breaking
- **Audit trail** — setiap perubahan versi tercatat di git history

## Update versi Argo Rollouts

```bash
# 1. Download versi baru
VERSION=v1.9.0  # ganti sesuai kebutuhan
curl -sL https://github.com/argoproj/argo-rollouts/releases/download/${VERSION}/install.yaml \
  -o argo-rollouts-controller-install.yaml

# 2. Review changelog: https://github.com/argoproj/argo-rollouts/releases/tag/${VERSION}
# 3. Commit
git add argo-rollouts-controller-install.yaml
git commit -m "chore(gitops): bump argo-rollouts to ${VERSION}"
```

## Verifikasi setelah ArgoCD sync

```bash
# Cek controller running
kubectl get pods -n argo-rollouts
# Expected: argo-rollouts-controller-* dan argo-rollouts-controller-metrics-* Running

# Cek CRD terdaftar
kubectl get crd rollouts.argoproj.io
# Expected: rollouts.argoproj.io   <date>
```

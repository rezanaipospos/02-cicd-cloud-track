# ArgoCD Installation — Non-HA (as-code, AD-17)

Versi: **v3.5.0-rc2** (non-HA)
File: `argocd-install.yaml` (di-commit lokal, bukan remote URL)

## Cara install (bootstrap — 1x manual)

```bash
# 1. Buat namespace
kubectl create namespace argocd

# 2. Apply manifest dari file lokal
kubectl apply -n argocd --server-side --force-conflicts -f bootstrap/install/argocd-install.yaml

# 3. Tunggu semua pod ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# 4. Apply AppProject + root-app
kubectl apply -n argocd -f bootstrap/project.yaml
kubectl apply -n argocd -f bootstrap/root-app.yaml

# 5. Ambil initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# 6. (Verifikasi) Port-forward (jalankan di terminal terpisah / tab baru)
kubectl port-forward svc/argocd-server -n argocd 8443:443
# Buka https://localhost:8443 (Abaikan warning HTTPS/insecure di browser karena menggunakan self-signed cert bawaan)
```

## Update versi ArgoCD

```bash
VERSION=v3.5.0  # ganti ke versi stable saat available
curl -sL "https://raw.githubusercontent.com/argoproj/argo-cd/${VERSION}/manifests/install.yaml" \
  -o argocd-install.yaml
kubectl apply -n argocd --server-side --force-conflicts -f argocd-install.yaml
git add argocd-install.yaml
git commit -m "chore(gitops): bump argocd to ${VERSION}"
```

# Progressive Delivery — Argo Rollouts + Canary

**Tujuan:** Install Argo Rollouts, konfigurasi Gateway API plugin, monitor dan promote canary deployment.

---

## Prasyarat

- GKE cluster running
- ArgoCD running + app backend-go ter-deploy
- Envoy Gateway running (Stage 09)

## Step 1: Install Argo Rollouts (Sudah Dilakukan di Stage GitOps)

Argo Rollouts secara default sudah di-install pada Stage 05 (GitOps) di `Step 1.5` untuk menghindari error CRD pada Kubernetes.

Jika belum, atau ingin memastikan status instalasinya secara manual, jalankan perintah berikut:

```bash
cd course-project/05-gitops/infrastructure/progressive-delivery/install

# Buat namespace jika belum ada
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -

# Install Argo Rollouts controller
kubectl apply -f argo-rollouts-controller-install.yaml
```

---

## Step 2: Konfigurasi Gateway API Plugin

Plugin dibutuhkan agar Rollout bisa pakai Envoy Gateway untuk traffic routing.

```bash
# Apply plugin config (buat ConfigMap di namespace argo-rollouts)
kubectl apply -f argo-rollouts-plugin-config.yaml

# Restart controller agar download plugin
kubectl rollout restart deployment argo-rollouts -n argo-rollouts
kubectl rollout status deployment argo-rollouts -n argo-rollouts

# Monitor download plugin (tunggu log ini muncul)
kubectl logs -n argo-rollouts -l app.kubernetes.io/name=argo-rollouts \
  --tail=20 | grep -i "plugin\|download\|gateway"
```

> **Catatan:** Plugin didownload dari GitHub. Pastikan Cloud NAT aktif agar pod bisa reach internet.

---

## Step 3: Verifikasi Setup

```bash
# Cek Rollout status
kubectl get rollout -n backend-development

# Status detail
kubectl argo rollouts get rollout backend-go-rollout -n backend-development

# Cek plugin terdaftar
kubectl get configmap argo-rollouts-config -n argo-rollouts -o yaml
```

---

## Step 4: Trigger Canary Release

Canary release terpicu saat CI update image tag di `patch/rollout.yaml` dan git push:

```bash
# Manual trigger (untuk test)
# Update image di patch/rollout.yaml
# git commit + push → ArgoCD sync → Rollout canary
```

---

## Step 5: Monitor Canary

```bash
# Watch rollout steps
kubectl argo rollouts get rollout backend-go-rollout \
  -n backend-development --watch

# Expected output saat canary:
# Status: Progressing
# Step: 1/4 (setWeight 50%)
# Canary pods: 1, Stable pods: 1
```

---

## Step 6: Promote / Rollback

```bash
# Promote ke step berikutnya (jika ada pause)
kubectl argo rollouts promote backend-go-rollout -n backend-development

# Promote langsung ke 100% (skip semua step)
kubectl argo rollouts promote backend-go-rollout -n backend-development --full

# Rollback (abort canary, kembali ke stable)
kubectl argo rollouts abort backend-go-rollout -n backend-development

# Undo ke revision sebelumnya
kubectl argo rollouts undo backend-go-rollout -n backend-development
```

---

## Troubleshooting

```bash
# Rollout stuck Progressing
kubectl logs -n argo-rollouts -l app.kubernetes.io/name=argo-rollouts \
  --tail=50 | grep -i "error\|backend-go"

# HPA error: spec.replicas tidak ada
# → Rollout controller belum register scale subresource
# → Restart argo-rollouts deployment
kubectl rollout restart deployment argo-rollouts -n argo-rollouts

# Service endpoint kosong
kubectl get endpoints backend-go-svc -n backend-development -o yaml
# Jika kosong → cek label pod vs selector service
kubectl get pods -n backend-development --show-labels
kubectl get service backend-go-svc -n backend-development -o jsonpath='{.spec.selector}'

# Gateway API plugin error
kubectl logs -n argo-rollouts -l app.kubernetes.io/name=argo-rollouts \
  --tail=30 | grep -i "plugin\|gateway"
# Jika "plugin not configured" → apply argo-rollouts-plugin-config.yaml lagi
```

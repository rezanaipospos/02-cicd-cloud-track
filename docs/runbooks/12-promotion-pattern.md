# Kustomize Promotion Pattern & Progressive Delivery (Argo Rollouts)

**Tujuan:** Memahami alur promosi image "build once, promote many" (AD-14) lintas environment (development → staging → production) menggunakan Kustomize, serta setup & pengoperasian Argo Rollouts untuk canary deployment.

---

## 1. Alur Promotion End-to-End (Build Once, Promote Many)

**Konsep:** Build sekali, deploy ke banyak environment. Image yang sama (digest/SHA sama) di-deploy ke development → staging → production.

### Flow
```
Commit → CI Build → Push Image (tag=SHA) → Update dev overlay → ArgoCD sync dev
                                                        ↓
                                          Copy tag ke staging overlay → ArgoCD sync staging
                                                                                   ↓
                                                                      Copy tag ke prod overlay → ArgoCD sync prod
```

### Detail Langkah:
1. **CI Build (merge ke `development` branch):**
   - Jenkins shared library build image `asia-southeast1-docker.pkg.dev/.../backend-go:abc123`
   - Push ke Artifact Registry
   - Update `overlays/development/kustomization.yaml` → `images[].newTag: "abc123"`
   - Git commit+push ke GitOps repo (branch gitops)

2. **Auto-deploy development:**
   - ArgoCD deteksi commit di `overlays/development/`
   - Sync → pod `backend-development` running image `...:abc123`

3. **Promosi ke staging (manual atau automation):**
   - Lead/automation copy tag `abc123` ke `overlays/staging/kustomization.yaml`:
     ```bash
     yq eval '.images[0].newTag = "abc123"' -i overlays/staging/kustomization.yaml
     ```
   - Git commit+push → ArgoCD sync → pod `backend-staging` running image `...:abc123`

4. **Promosi ke production (manual, gated input):**
   - Copy tag yang sama ke `overlays/production/kustomization.yaml`:
     ```bash
     yq eval '.images[0].newTag = "abc123"' -i overlays/production/kustomization.yaml
     ```
   - Git commit+push → ArgoCD sync → pod `backend-production` running image `...:abc123`

### Keuntungan build-once-promote:
- **Consistency:** Binary identical lintas env → "works in staging, works in prod"
- **Auditability:** Tag SHA bisa lacak ke commit exact
- **Rollback:** Revert ke tag SHA sebelumnya = git revert commit

---

## 2. Simulasi Promosi Manual (yq / sed)

### Persiapan:
```bash
# Pastikan dev overlay sudah ter-update dengan tag (mis. abc123)
cd course-project/05-gitops/applications/backend-go/overlays

# Cek tag di development
yq eval '.images[0].newTag' development/kustomization.yaml
# Output: abc123
```

### Promosi ke staging:
```bash
# Update staging overlay dengan tag yang sama
yq eval '.images[0].newTag = "abc123"' -i staging/kustomization.yaml

# Verify change
yq eval '.images[0].newTag' staging/kustomization.yaml
# Output: abc123

# Commit & push (ArgoCD auto-sync)
git add staging/kustomization.yaml
git commit -m "chore(gitops): promote backend-go:abc123 to staging"
git push origin main
```

### Promosi ke production:
```bash
# Update production overlay dengan tag yang sama
yq eval '.images[0].newTag = "abc123"' -i production/kustomization.yaml

# Verify change
yq eval '.images[0].newTag' production/kustomization.yaml
# Output: abc123

# Commit & push (ArgoCD auto-sync)
git add production/kustomization.yaml
git commit -m "chore(gitops): promote backend-go:abc123 to production"
git push origin main
```

### Alternatif dengan sed (jika yq tidak tersedia):
```bash
# Promosi staging (sed)
sed -i '' 's/newTag: ".*"/newTag: "abc123"/' staging/kustomization.yaml

# Promosi production (sed)
sed -i '' 's/newTag: ".*"/newTag: "abc123"/' production/kustomization.yaml
```

### Verifikasi ArgoCD sync:
```bash
# Cek status sync staging
kubectl get applications -n argocd backend-go-staging -o jsonpath='{.status.sync.status}'
# Output: Synced

# Cek status sync production
kubectl get applications -n argocd backend-go-prod -o jsonpath='{.status.sync.status}'
# Output: Synced
```

---

## 3. Verifikasi Multi-Environment

### Cek pods running di 3 namespace:
```bash
# Development
kubectl get pods -n backend-development -l app=backend-go

# Staging
kubectl get pods -n backend-staging -l app=backend-go

# Production
kubectl get pods -n backend-production -l app=backend-go
```

### Verifikasi image digest sama (build-once):
```bash
# Cek image di development
kubectl get pods -n backend-development -o jsonpath='{.items[0].spec.containers[0].image}'

# Cek image di staging
kubectl get pods -n backend-staging -o jsonpath='{.items[0].spec.containers[0].image}'

# Cek image di production
kubectl get pods -n backend-production -o jsonpath='{.items[0].spec.containers[0].image}'

# Ketiga output harus IDENTIK (mis. asia-southeast1-docker.pkg.dev/.../backend-go:abc123)
```

### Cek replicas (sesuai konfigurasi overlay):
```bash
# Development: 1 replica
kubectl get deployment backend-go-backend-go -n backend-development -o jsonpath='{.spec.replicas}'

# Staging: 2 replicas
kubectl get deployment backend-go-backend-go -n backend-staging -o jsonpath='{.spec.replicas}'

# Production: 3 replicas
kubectl get deployment backend-go-backend-go -n backend-production -o jsonpath='{.spec.replicas}'
```

### Cek ArgoCD applications sync status:
```bash
kubectl get applications -n argocd
# Semua backend-go-* harus Synced (Health: Healthy)
```

---

## 4. Install Argo Rollouts (Progressive Delivery)

**Tujuan:** Install Argo Rollouts sebagai platform service via ArgoCD infrastructure Application.

### Langkah:
1. Update `05-gitops/infrastructure/kustomization.yaml` (Story 5.3 sudah diupdate)
2. Commit dan push → ArgoCD auto-sync → Argo Rollouts installed

```bash
# Commit perubahan infrastructure kustomization
cd course-project/05-gitops
git add infrastructure/kustomization.yaml
git commit -m "chore(platform): add Argo Rollouts install manifest"
git push origin main

# Tunggu ArgoCD sync (~30s)
kubectl get applications -n argocd infrastructure -o jsonpath='{.status.sync.status}'

# Cek Argo Rollouts controller running
kubectl get pods -n argo-rollouts
# Expected: argo-rollouts-controller-<hash> Running

# Verifikasi CRD
kubectl get crd rollouts.argoproj.io
# Expected: rollouts.argoproj.io   <date>
```

### Verify install:
```bash
# Controller pod
kubectl get pods -n argo-rollouts -l app=argo-rollouts

# CRD registered
kubectl get crd | grep rollouts.argoproj.io
```

---

## 5. Trigger Canary Release

**Tujuan:** Trigger canary deployment dengan update image tag → amati step canary (20% → 40% → 100%).

### Langkah:
1. Update image tag di overlay development (mis. `abc123`)
2. Commit+push → ArgoCD sync → Rollout active
3. Pantau rollout step via CLI

```bash
# Update image tag di overlay development
cd course-project/05-gitops/applications/backend-go/overlays/development

# Cek tag sebelum
yq eval '.images[0].newTag' kustomization.yaml

# Update ke tag baru (mis. git SHA abc123)
yq eval '.images[0].newTag = "abc123"' -i kustomization.yaml

# Commit & push
git add kustomization.yaml
git commit -m "feat(gitops): release backend-go:abc123 canary"
git push origin main

# Tunggu ArgoCD sync
kubectl get applications -n argocd backend-go-dev -o jsonpath='{.status.sync.status}'

# Pantau rollout step (otomatis atau manual promote)
kubectl argo rollouts get rollout backend-go -n backend-development --watch
```

### Expected rollout steps:
```
Step 1/5: setWeight 20 (pause)
Step 2/5: pause (wait for promote)
Step 3/5: setWeight 40 (pause)
Step 4/5: pause (wait for promote)
Step 5/5: setWeight 100
```

### Traffic split verification:
```bash
# Lihat pod labels (canary vs stable)
kubectl get pods -n backend-development --show-labels | grep backend-go
# Pod canary: argoproj.io/revision: <canary-revision>
# Pod stable: argoproj.io/revision: <stable-revision>

# Status detail rollout
kubectl argo rollouts get rollout backend-go -n backend-development
# Output: Canary: X pods, Stable: Y pods (total Z replicas)
```

---

## 6. Promote / Rollback Manual

**Tujuan:** Test promote (next step) dan rollback (abort canary).

### Promote ke step berikutnya:
```bash
# Saat rollout pause (antar step), promote manual
kubectl argo rollouts promote backend-go -n backend-development

# Tunggu step berikutnya
kubectl argo rollouts get rollout backend-go -n backend-development --watch
```

### Rollback (abort canary):
```bash
# Abort canary, kembali ke stable (current production)
kubectl argo rollouts abort backend-go -n backend-development

# Verify rollback (replica semua ke stable)
kubectl argo rollouts get rollout backend-go -n backend-development
# Expected: All pods di stable, canary replicas 0
```

### Undo (ke revision sebelumnya):
```bash
# Undo ke revision sebelumnya (jika abort tidak cukup)
kubectl argo rollouts undo backend-go -n backend-development

# Verify
kubectl argo rollouts get rollout backend-go -n backend-development
```

### Verifikasi rollback:
```bash
# Cek image pod (harus kembali ke stable image)
kubectl get pods -n backend-development -l app=backend-go -o jsonpath='{.items[0].spec.containers[0].image}'
```

---

## 7. Verifikasi Traffic Split

**Tujuan:** Verifikasi Argo Rollouts traffic shifting works (canary vs stable replicas).

### Check replica distribution:
```bash
# Status detail rollout (canary vs stable)
kubectl argo rollouts get rollout backend-go -n backend-development

# Expected output format:
# Name:            backend-go
# Namespace:       backend-development
# Status:          ◌ Paused (Step 2/5)
# Image:           asia-southeast1-docker.pkg.dev/.../backend-go:abc123
# Strategy:        Canary
#   Step:          2/5
#   SetWeight:     40
#   Pause:         {}
# Pods:
#   Canary:        1 replicas (20%)
#   Stable:        4 replicas (80%)
#   Total:         5 replicas
```

### Check pod labels:
```bash
# Lihat label argoproj.io/revision
kubectl get pods -n backend-development -l app=backend-go --show-labels

# Output example:
# backend-go-abc123-xyz   1/1   Running   0   5m   app=backend-go,argoproj.io/revision=2
# backend-go-abc123-abc   1/1   Running   0   5m   app=backend-go,argoproj.io/revision=2
# backend-go-def456-123   1/1   Running   0   1h   app=backend-go,argoproj.io/revision=1
# backend-go-def456-456   1/1   Running   0   1h   app=backend-go,argoproj.io/revision=1
# backend-go-def456-789   1/1   Running   0   1h   app=backend-go,argoproj.io/revision=1

# Pod dengan revision sama = dalam satu group (canary atau stable)
# Pod dengan revision berbeda = traffic split berjalan
```

### Cek service selector (automated by Argo Rollouts):
```bash
# Canary service selector diupdate otomatis oleh Argo Rollouts
kubectl get svc backend-go-canary-svc -n backend-development -o yaml | grep -A5 selector:

# Stable service selector diupdate otomatis oleh Argo Rollouts
kubectl get svc backend-go-stable-svc -n backend-development -o yaml | grep -A5 selector:
```

---

## 8. Keterbatasan Replica-Based Canary

**Catatan penting (untuk peserta):**
Argo Rollouts tanpa service mesh menggunakan **replica-based traffic split**, bukan request-based:

| Aspek | Replica-based (course) | Request-based (Istio) |
|-------|------------------------|------------------------|
| Traffic control | % replica di canary | % request ke canary |
| Granularity | Per-pod | Per-request |
| Accuracy | Tidak presisi (integer replicas) | Presisi (mis. 23.5% traffic) |
| Use case | Development, testing | Production, traffic-sensitive |

### Cek replica-based behavior:
```bash
# SetWeight 20% dengan 5 replicas:
kubectl argo rollouts get rollout backend-go -n backend-development

# Expected:
# Canary: 1 replicas (20%)  ← 5 × 0.20 = 1 (integer)
# Stable: 4 replicas (80%)

# SetWeight 25% dengan 5 replicas:
# Canary: 1 replicas (20%)  ← round(5 × 0.25) = 1
# Stable: 4 replicas (80%)

# SetWeight 40% dengan 5 replicas:
# Canary: 2 replicas (40%)  ← 5 × 0.40 = 2
# Stable: 3 replicas (60%)

# Kesimpulan: traffic split tidak presisi karena integer replicas.
# Di production traffic tinggi, efeknya minimal (per-pod ≈ per-request).
# Untuk presisi tinggi, gunakan service mesh (Istio/Linkerd).
```

### Rekomendasi untuk production:
- Development/testing: replica-based cukup (course ini pakai ini)
- Production traffic-sensitive: tambahkan service mesh (Istio/Linkerd) → request-based split
- Argo Rollouts support both modes: `strategy.canary.trafficRouting` (Istio/Lockerman)

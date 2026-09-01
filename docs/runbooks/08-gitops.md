# GitOps — ArgoCD + Kustomize + App-of-Apps

**Tujuan:** Install ArgoCD, connect ke GitHub, apply app-of-apps pattern.

---

## Prasyarat

- GKE cluster running (Stage 04 applied)
- `kubectl` configured ke cluster
- Domain ArgoCD sudah siap (`argocd.naipospos.cloud`)
- SSL cert sudah di-apply sebagai Kubernetes Secret (lihat `03-ssl.md`)

---

## Step 1: Install ArgoCD

```bash
cd course-project/05-gitops

kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f bootstrap/install/argocd-install.yaml

# Tunggu ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=300s

# Ambil initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

---

## Step 1.5: Install Envoy Gateway & Argo Rollouts (Prasyarat CRD & Controller)

Sebelum kita men-deploy aplikasi (terutama backend-go yang membutuhkan resource `Rollout` dan `HTTPRoute`), kita harus memastikan Envoy Gateway dan Argo Rollouts sudah terinstall di cluster agar Kubernetes API server mengenali CRD tersebut.

### A. Install Envoy Gateway via Helm

```bash
# Install Envoy Gateway
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.8.2 \
  -n envoy-gateway-system \
  --create-namespace

# Tunggu controller ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=envoy-gateway \
  -n envoy-gateway-system --timeout=120s
```

### B. Install Argo Rollouts via Local Manifest

```bash
# Buat namespace argo-rollouts
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -

# Install Argo Rollouts controller
kubectl apply -f infrastructure/progressive-delivery/install/argo-rollouts-controller-install.yaml

# Tunggu controller ready
kubectl wait --for=condition=ready pod \
  -l app=argo-rollouts \
  -n argo-rollouts --timeout=120s
```

---

## Step 2: Connect ArgoCD ke GitHub

ArgoCD perlu credentials untuk pull manifest dari private repo.

### Via Kubernetes Secret (recommended):

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: repo-github-gitops
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: "https://github.com/YOUR_ORG/YOUR_REPO.git"
  username: "YOUR_GITHUB_USERNAME"
  password: "YOUR_GITHUB_CLASSIC_PAT"
EOF
```

> **Gunakan Classic PAT** (bukan Fine-grained) dengan scope `repo` untuk menghindari issue
> dengan organization repository.

### Via ArgoCD UI:

Settings → Repositories → Connect Repo → HTTPS → isi URL + username + token → Connect

---

## Step 3: Verifikasi + Fix In-Cluster Connection

```bash
# Cek cluster secret
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=cluster

# Jika tidak ada, buat manual:
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: in-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: "in-cluster"
  server: "https://kubernetes.default.svc"
  config: |
    {
      "tlsClientConfig": {
        "insecure": false
      }
    }
EOF

kubectl rollout restart deploy/argocd-server -n argocd
```

---

## Step 4: Apply AppProject + Root App-of-Apps

> **PENTING:** Pastikan repo sudah connected (status Successful) SEBELUM apply root-app.

```bash
# 1. Apply AppProject
kubectl apply -f bootstrap/project.yaml

# 2. Apply root app-of-apps
kubectl apply -f bootstrap/root-app.yaml

# 3. Monitor sync
kubectl get applications -n argocd
```

---

## Step 5: Debug Aplikasi

```bash
# Status detail aplikasi
kubectl describe application root-app -n argocd | grep -A10 "Conditions\|Message\|Status"

# Semua aplikasi
kubectl get applications -n argocd -o wide

# Trigger sync manual
argocd app sync backend-go-dev
argocd app sync infrastructure

# Cek koneksi dari cluster ke GitHub (test Cloud NAT)
kubectl run test-github --rm -it --restart=Never --image=curlimages/curl -- \
  curl -sI https://github.com --max-time 10
```

**Error umum:**

| Error | Penyebab | Fix |
|-------|----------|-----|
| `revision HEAD must be resolved` | Repo belum connected | Connect repo dulu |
| `context canceled` | Timeout — tidak bisa reach github.com | Cek Cloud NAT |
| `path not found` | Path di Application YAML salah | Cek field `path:` |
| `Write access not granted` | Fine-grained PAT issue dengan org repo | Pakai Classic PAT |

---

## Path yang Benar

| Application | `path` di YAML |
|-------------|----------------|
| root-app | `course-project/05-gitops/bootstrap/apps` |
| backend-go-dev | `course-project/05-gitops/applications/development/backend-go` |
| backend-go-staging | `course-project/05-gitops/applications/staging/backend-go` |
| backend-go-prod | `course-project/05-gitops/applications/production/backend-go` |
| infrastructure | `course-project/05-gitops/infrastructure` |

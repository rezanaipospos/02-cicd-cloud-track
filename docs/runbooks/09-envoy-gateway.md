# Envoy Gateway — Expose Domain Publik

**Tujuan:** Install Envoy Gateway dan expose ArgoCD UI + backend-go-dev via domain publik dengan TLS.

---

## Prasyarat

- GKE cluster running
- ArgoCD sudah terinstall (Stage 05)
- SSL cert sudah di-apply sebagai Kubernetes Secret (lihat `03-ssl.md`)
- Domain sudah siap: `argocd.naipospos.cloud`, `backend-go-dev.naipospos.cloud`

## Step 1: Install Envoy Gateway Controller (Sudah Dilakukan di Stage GitOps)

Envoy Gateway secara default sudah di-install pada Stage 05 (GitOps) di `Step 1.5` untuk menghindari error CRD pada Kubernetes. 

Jika belum, atau ingin memastikan kembali status instalasinya, jalankan perintah berikut:

```bash
# Install Envoy Gateway jika belum ada
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.8.2 \
  -n envoy-gateway-system \
  --create-namespace

# Verifikasi dan tunggu controller ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=envoy-gateway \
  -n envoy-gateway-system --timeout=120s

# Cek pod status
kubectl get pods -n envoy-gateway-system
```

---

## Step 2: Label Namespace

Gateway hanya route ke namespace yang punya label `shared-gateway-access: "true"`.

```bash
# ArgoCD
kubectl label namespace argocd shared-gateway-access=true --overwrite

# Backend development
kubectl label namespace backend-development shared-gateway-access=true --overwrite

# Vault
kubectl label namespace backend-development shared-gateway-access=true --overwrite

# Verifikasi
kubectl get namespace -l shared-gateway-access=true
```

---

## Step 3: Set ArgoCD ke Insecure Mode

TLS termination di Envoy Gateway, ArgoCD backend pakai HTTP:

```bash
kubectl -n argocd patch configmap argocd-cmd-params-cm --type merge \
  -p='{"data":{"server.insecure":"true"}}'

kubectl -n argocd rollout restart deployment argocd-server
kubectl -n argocd rollout status deployment argocd-server
```

---

## Step 4: Apply Gateway + Routes

```bash
cd course-project/05-gitops/infrastructure/gateway-api

# Apply GatewayClass + Gateway
kubectl apply -f gateway.yaml

# Apply ArgoCD route (HTTP redirect + HTTPS)
kubectl apply -f argocd-route.yaml

# Apply backend-go route (setelah backend-go-dev namespace siap)
# File ada di: applications/development/backend-go/network/http-route.yaml
# Route ini di-manage ArgoCD via app-of-apps
```

---

## Step 5: Dapatkan IP LoadBalancer

```bash
# Tunggu IP assigned (1-2 menit)
kubectl get gateway course-gateway -n argocd -o jsonpath='{.status.addresses[0].value}'
# Output: 34.xxx.xxx.xxx
```

---

## Step 6: Set DNS A Records

Arahkan semua subdomain ke IP yang sama:

| DNS Record | Type | Value |
|---|---|---|
| `argocd.naipospos.cloud` | A | `34.xxx.xxx.xxx` |
| `backend-go-dev.naipospos.cloud` | A | `34.xxx.xxx.xxx` (IP sama) |

> Dengan wildcard cert `*.naipospos.cloud`, satu Gateway cover semua subdomain.

---

## Step 7: Verifikasi

```bash
# ArgoCD
curl -I https://argocd.naipospos.cloud
# Expected: 200 OK atau 302 redirect ke /login

# Backend-go-dev
curl -I https://backend-go-dev.naipospos.cloud
# Expected: 200 OK (jika pod running)

# Cek TLS cert
echo | openssl s_client -connect argocd.naipospos.cloud:443 \
  -servername argocd.naipospos.cloud 2>/dev/null \
  | openssl x509 -noout -subject -dates
# subject: CN=*.naipospos.cloud
```

---

## Troubleshooting

```bash
# Gateway tidak mendapat IP
kubectl describe gateway course-gateway -n argocd

# Route tidak match
kubectl describe httproute -n argocd
kubectl describe httproute -n backend-development

# Namespace tidak diizinkan Gateway
kubectl get namespace -l shared-gateway-access=true
# Tambah label jika belum ada

# ArgoCD masih HTTPS backend (502 error)
kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml | grep insecure

# Envoy logs
kubectl logs -n envoy-gateway-system \
  -l app.kubernetes.io/name=envoy-gateway --tail=30
```

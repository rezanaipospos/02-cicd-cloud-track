# Gateway API — Envoy Gateway

Expose services via Envoy Gateway (Gateway API standard).

## Prasyarat

1. **Envoy Gateway controller** sudah terinstall di cluster:
   ```bash
   # Install Envoy Gateway (versi terbaru)
   kubectl apply -f https://github.com/envoyproxy/gateway/releases/latest/download/install.yaml
   
   # Atau via Helm:
   helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.4.0 -n envoy-gateway-system --create-namespace
   ```

2. **Label namespace** yang mau akses gateway:
   ```bash
   kubectl label namespace argocd shared-gateway-access=true
   ```

3. **TLS Secret** (cert yang di-generate sendiri):
   ```bash
   # Buat TLS secret dari cert + key yang sudah kamu generate
   kubectl create secret tls ssl-cert-naipospos-cloud \
     --cert=path/to/fullchain.pem \
     --key=path/to/privkey.pem \
     -n argocd
   ```

4. **DNS A record:** `argocd.naipospos.cloud` → IP LoadBalancer Gateway
   ```bash
   # Setelah gateway ready, cek IP:
   kubectl get gateway course-gateway -n argocd -o jsonpath='{.status.addresses[0].value}'
   ```

## ArgoCD insecure mode (penting!)

ArgoCD server default listen HTTPS (self-signed). Karena TLS termination di Gateway, 
ArgoCD server harus di-set **insecure mode** (HTTP backend):

```bash
# Patch ArgoCD server deployment
kubectl -n argocd patch deployment argocd-server --type json -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--insecure"}
]'

# Atau via argocd-cmd-params-cm configmap:
kubectl -n argocd patch configmap argocd-cmd-params-cm --type merge -p='{"data":{"server.insecure":"true"}}'
kubectl -n argocd rollout restart deployment argocd-server
```

## Verifikasi

```bash
# Gateway status
kubectl get gateway course-gateway -n argocd

# HTTPRoute status
kubectl get httproute -n argocd

# Akses via browser
# https://argocd.naipospos.cloud
```

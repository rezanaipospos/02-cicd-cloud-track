#!/usr/bin/env bash
# ============================================================================
# Script: vault-init.sh
# Purpose: Mengonfigurasi authentication & secrets engine di Vault (Kubernetes-native)
# ============================================================================
set -euo pipefail

VAULT_NAMESPACE="vault"

echo "[INFO] Menunggu pod vault-0 ready..."
kubectl wait --for=condition=Ready pod/vault-0 -n "$VAULT_NAMESPACE" --timeout=300s

echo "[INFO] Memeriksa status otentikasi Vault..."
VAULT_TOKEN=""
if ! kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault token lookup &>/dev/null; then
    echo "[WARN] Vault belum terotentikasi (403 Permission Denied atau token tidak valid)."
    echo -n "Silakan masukkan Vault Root Token Anda: "
    read -r -s VAULT_TOKEN
    echo ""
    if [ -z "$VAULT_TOKEN" ]; then
        echo "[ERROR] Token tidak boleh kosong!"
        exit 1
    fi
else
    echo "[INFO] Vault sudah terotentikasi."
fi

# Helper function untuk menjalankan command Vault
run_vault() {
    if [ -n "$VAULT_TOKEN" ]; then
        kubectl exec -i -n "$VAULT_NAMESPACE" vault-0 -- env VAULT_TOKEN="$VAULT_TOKEN" "$@"
    else
        kubectl exec -i -n "$VAULT_NAMESPACE" vault-0 -- "$@"
    fi
}

echo "[INFO] Mengaktifkan Kubernetes Auth Method..."
run_vault vault auth enable kubernetes || true

echo "[INFO] Mengonfigurasi Kubernetes Auth dengan service account local..."
run_vault vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc"

echo "[INFO] Mengaktifkan KV Secrets Engine v2 di path 'secret/'..."
run_vault vault secrets enable -path=secret kv-v2 || true

echo "[INFO] Menulis policy read-only 'backend-go'..."
run_vault vault policy write backend-go - <<'EOF'
path "secret/data/backend-go/*" {
  capabilities = ["read"]
}
path "secret/data/backend-go-cinema/*" {
  capabilities = ["read"]
}
path "secret/data/backend-go-payment/*" {
  capabilities = ["read"]
}
EOF

echo "[INFO] Membuat Kubernetes roles untuk backend-go (dev, staging, prod)..."

# Role untuk Development
run_vault vault write auth/kubernetes/role/backend-go-dev \
    bound_service_account_names=backend-go-backend-go,backend-go-cinema-backend-go,backend-go-payment-backend-go \
    bound_service_account_namespaces=backend-development \
    policies=backend-go \
    ttl=1h

# Role untuk Staging
run_vault vault write auth/kubernetes/role/backend-go-staging \
    bound_service_account_names=backend-go-backend-go,backend-go-cinema-backend-go,backend-go-payment-backend-go \
    bound_service_account_namespaces=backend-staging \
    policies=backend-go \
    ttl=1h

# Role untuk Production
run_vault vault write auth/kubernetes/role/backend-go-prod \
    bound_service_account_names=backend-go-backend-go,backend-go-cinema-backend-go,backend-go-payment-backend-go \
    bound_service_account_namespaces=backend-production \
    policies=backend-go \
    ttl=1h

echo "[✓] Vault post-initialization selesai!"

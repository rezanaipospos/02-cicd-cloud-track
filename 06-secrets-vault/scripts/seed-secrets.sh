#!/usr/bin/env bash
# ============================================================================
# Script: seed-secrets.sh
# Purpose: Mengisi (seed) mock secrets per-environment ke Vault KV v2 engine
# ============================================================================
set -euo pipefail

VAULT_NAMESPACE="vault"

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

echo "[INFO] Menghasilkan dummy RSA Private Key untuk banking..."
DUMMY_PEM_DEV=$(openssl genrsa 2048 2>/dev/null)
DUMMY_PEM_STG=$(openssl genrsa 2048 2>/dev/null)
DUMMY_PEM_PRD=$(openssl genrsa 2048 2>/dev/null)

echo "[INFO] Mengisi secrets untuk Development (secret/backend-go/dev)..."
run_vault vault kv put secret/backend-go/dev \
    APP_DB_URL="postgres://db-user-dev:changeme@postgres-dev.backend-development.svc.cluster.local:5432/db_dev?sslmode=disable" \
    APP_DB_PASSWORD="changeme" \
    APP_JWT_SECRET="dev-jwt-secret-key-32-chars-long-or-more" \
    APP_SECRET_KEY="dev-encryption-salt-secret-key-here" \
    APP_NEWRELIC_KEY="nr-lic-key-dev-placeholder" \
    APP_BANKING_PRIVATE_KEY="$DUMMY_PEM_DEV"

echo "[INFO] Mengisi secrets untuk Cinema Development (secret/backend-go-cinema/dev)..."
run_vault vault kv put secret/backend-go-cinema/dev \
    APP_DB_URL="postgres://db-user-cinema-dev:changeme@postgres-dev.backend-development.svc.cluster.local:5432/db_dev_cinema?sslmode=disable" \
    APP_DB_PASSWORD="changeme" \
    APP_JWT_SECRET="dev-cinema-jwt-secret-key-32-chars-long-or-more" \
    APP_SECRET_KEY="dev-cinema-encryption-salt-secret-key-here" \
    APP_NEWRELIC_KEY="nr-lic-key-cinema-dev-placeholder" \
    APP_BANKING_PRIVATE_KEY="$DUMMY_PEM_DEV"

echo "[INFO] Mengisi secrets untuk Payment Development (secret/backend-go-payment/dev)..."
run_vault vault kv put secret/backend-go-payment/dev \
    APP_DB_URL="postgres://db-user-payment-dev:changeme@postgres-dev.backend-development.svc.cluster.local:5432/db_dev_payment?sslmode=disable" \
    APP_DB_PASSWORD="changeme" \
    APP_JWT_SECRET="dev-payment-jwt-secret-key-32-chars-long-or-more" \
    APP_SECRET_KEY="dev-payment-encryption-salt-secret-key-here" \
    APP_NEWRELIC_KEY="nr-lic-key-payment-dev-placeholder" \
    APP_BANKING_PRIVATE_KEY="$DUMMY_PEM_DEV"

echo "[INFO] Mengisi secrets untuk Staging (secret/backend-go/staging)..."
run_vault vault kv put secret/backend-go/staging \
    APP_DB_URL="postgres://db-user-staging:changeme@postgres-staging.backend-staging.svc.cluster.local:5432/db_staging?sslmode=disable" \
    APP_DB_PASSWORD="changeme" \
    APP_JWT_SECRET="stg-jwt-secret-key-32-chars-long-or-more" \
    APP_SECRET_KEY="stg-encryption-salt-secret-key-here" \
    APP_NEWRELIC_KEY="nr-lic-key-stg-placeholder" \
    APP_BANKING_PRIVATE_KEY="$DUMMY_PEM_STG"

echo "[INFO] Mengisi secrets untuk Cinema Staging (secret/backend-go-cinema/staging)..."
run_vault vault kv put secret/backend-go-cinema/staging \
    APP_DB_URL="postgres://db-user-cinema-staging:changeme@postgres-staging.backend-staging.svc.cluster.local:5432/db_staging_cinema?sslmode=disable" \
    APP_DB_PASSWORD="changeme" \
    APP_JWT_SECRET="stg-cinema-jwt-secret-key-32-chars-long-or-more" \
    APP_SECRET_KEY="stg-cinema-encryption-salt-secret-key-here" \
    APP_NEWRELIC_KEY="nr-lic-key-cinema-stg-placeholder" \
    APP_BANKING_PRIVATE_KEY="$DUMMY_PEM_STG"

echo "[INFO] Mengisi secrets untuk Payment Staging (secret/backend-go-payment/staging)..."
run_vault vault kv put secret/backend-go-payment/staging \
    APP_DB_URL="postgres://db-user-payment-staging:changeme@postgres-staging.backend-staging.svc.cluster.local:5432/db_staging_payment?sslmode=disable" \
    APP_DB_PASSWORD="changeme" \
    APP_JWT_SECRET="stg-payment-jwt-secret-key-32-chars-long-or-more" \
    APP_SECRET_KEY="stg-payment-encryption-salt-secret-key-here" \
    APP_NEWRELIC_KEY="nr-lic-key-payment-stg-placeholder" \
    APP_BANKING_PRIVATE_KEY="$DUMMY_PEM_STG"

echo "[INFO] Mengisi secrets untuk Production (secret/backend-go/prod)..."
run_vault vault kv put secret/backend-go/prod \
    APP_DB_URL="postgres://db-user-prod:changeme@postgres-prod.backend-production.svc.cluster.local:5432/db_prod?sslmode=disable" \
    APP_DB_PASSWORD="changeme" \
    APP_JWT_SECRET="prod-jwt-secret-key-32-chars-long-or-more-critical" \
    APP_SECRET_KEY="prod-encryption-salt-secret-key-here-strong" \
    APP_NEWRELIC_KEY="nr-lic-key-prod-placeholder-real" \
    APP_BANKING_PRIVATE_KEY="$DUMMY_PEM_PRD"

echo "[INFO] Mengisi secrets untuk Cinema Production (secret/backend-go-cinema/prod)..."
run_vault vault kv put secret/backend-go-cinema/prod \
    APP_DB_URL="postgres://db-user-cinema-prod:changeme@postgres-prod.backend-production.svc.cluster.local:5432/db_prod_cinema?sslmode=disable" \
    APP_DB_PASSWORD="changeme" \
    APP_JWT_SECRET="prod-cinema-jwt-secret-key-32-chars-long-or-more-critical" \
    APP_SECRET_KEY="prod-cinema-encryption-salt-secret-key-here-strong" \
    APP_NEWRELIC_KEY="nr-lic-key-cinema-prod-placeholder-real" \
    APP_BANKING_PRIVATE_KEY="$DUMMY_PEM_PRD"

echo "[INFO] Mengisi secrets untuk Payment Production (secret/backend-go-payment/prod)..."
run_vault vault kv put secret/backend-go-payment/prod \
    APP_DB_URL="postgres://db-user-payment-prod:changeme@postgres-prod.backend-production.svc.cluster.local:5432/db_prod_payment?sslmode=disable" \
    APP_DB_PASSWORD="changeme" \
    APP_JWT_SECRET="prod-payment-jwt-secret-key-32-chars-long-or-more-critical" \
    APP_SECRET_KEY="prod-payment-encryption-salt-secret-key-here-strong" \
    APP_NEWRELIC_KEY="nr-lic-key-payment-prod-placeholder-real" \
    APP_BANKING_PRIVATE_KEY="$DUMMY_PEM_PRD"

echo "[✓] Seeding mock secrets ke Vault selesai!"

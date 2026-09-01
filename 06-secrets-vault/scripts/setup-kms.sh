#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Script: setup-kms.sh
# Purpose: Setup GCP Cloud KMS untuk Vault auto-unseal via Workload Identity
# 
# Eksekusi: ./setup-kms.sh [PROJECT_ID] [REGION]
# Contoh: ./setup-kms.sh my-gcp-project asia-southeast1
#
# Dibuat untuk Story 6.1: Vault Secret Management + External Secrets Operator
# ============================================================================

# Colors untuk output yang lebih jelas
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DEFAULT_REGION="asia-southeast1"

# Fungsi untuk menampilkan pesan error
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Fungsi untuk menampilkan pesan info
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Fungsi untuk menampilkan pesan warning
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Fungsi untuk menampilkan progress
progress() {
    echo -e "${GREEN}[✓]${NC} $1"
}

# Fungsi untuk memverifikasi command tersedia
check_command() {
    if ! command -v "$1" &> /dev/null; then
        error_exit "Command '$1' tidak ditemukan. Silakan install terlebih dahulu."
    fi
}

# Parse arguments
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [PROJECT_ID] [REGION]"
    echo "Example: $0 my-gcp-project asia-southeast1"
    echo ""
    echo "Jika PROJECT_ID tidak disediakan, script akan mencoba membaca dari env atau config gcloud"
    exit 0
fi

PROJECT_ID="${1}"
REGION="${2:-$DEFAULT_REGION}"

# Validasi input
if [[ -z "$PROJECT_ID" ]]; then
    error_exit "PROJECT_ID tidak boleh kosong"
fi

if [[ -z "$REGION" ]]; then
    error_exit "REGION tidak boleh kosong"
fi

# Check prerequisites
info "Memeriksa prerequisites..."
check_command "gcloud"

# Verifikasi gcloud sudah login dan project valid
info "Memverifikasi akses ke GCP..."
ACTIVE_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
if [[ -z "$ACTIVE_PROJECT" ]]; then
    warn "Tidak ada project aktif di gcloud config. Menggunakan PROJECT_ID dari parameter: $PROJECT_ID"
else
    if [[ "$ACTIVE_PROJECT" != "$PROJECT_ID" ]]; then
        warn "Project aktif di gcloud config ($ACTIVE_PROJECT) berbeda dengan parameter ($PROJECT_ID). Menggunakan parameter."
    fi
fi

# Set project untuk session ini
gcloud config set project "$PROJECT_ID" --quiet

# Enable Cloud KMS API jika belum
info "Memeriksa Cloud KMS API..."
if ! gcloud services list --enabled --filter="name:cloudkms.googleapis.com" --format="value(name)" | grep -q "cloudkms.googleapis.com"; then
    warn "Cloud KMS API belum di-enable. Meng-enable API..."
    gcloud services enable cloudkms.googleapis.com --project="$PROJECT_ID"
    progress "Cloud KMS API berhasil di-enable"
else
    progress "Cloud KMS API sudah di-enable"
fi

# Step 1: Buat KMS Key Ring
info "Step 1: Membuat KMS Key Ring..."
KEY_RING_NAME="vault-unseal"
KEY_RING_LOCATION="${REGION}"

# Cek apakah key ring sudah ada
if gcloud kms keyrings describe "$KEY_RING_NAME" --location="$KEY_RING_LOCATION" --project="$PROJECT_ID" &>/dev/null; then
    progress "Key ring '$KEY_RING_NAME' sudah ada di location '$KEY_RING_LOCATION'"
else
    gcloud kms keyrings create "$KEY_RING_NAME" \
        --location="$KEY_RING_LOCATION" \
        --project="$PROJECT_ID"
    progress "Key ring '$KEY_RING_NAME' berhasil dibuat di location '$KEY_RING_LOCATION'"
fi

# Step 2: Buat Crypto Key untuk Vault auto-unseal
info "Step 2: Membuat Crypto Key..."
CRYPTO_KEY_NAME="vault-unseal-key"
KEY_PROTECTION_LEVEL="software"  # Untuk lab, gunakan software. Untuk production bisa "hsm"

# Cek apakah crypto key sudah ada
if gcloud kms keys describe "$CRYPTO_KEY_NAME" \
    --keyring="$KEY_RING_NAME" \
    --location="$KEY_RING_LOCATION" \
    --project="$PROJECT_ID" &>/dev/null; then
    progress "Crypto key '$CRYPTO_KEY_NAME' sudah ada di key ring '$KEY_RING_NAME'"
else
    gcloud kms keys create "$CRYPTO_KEY_NAME" \
        --keyring="$KEY_RING_NAME" \
        --location="$KEY_RING_LOCATION" \
        --purpose="encryption" \
        --protection-level="$KEY_PROTECTION_LEVEL" \
        --project="$PROJECT_ID"
    progress "Crypto key '$CRYPTO_KEY_NAME' berhasil dibuat dengan protection level '$KEY_PROTECTION_LEVEL'"
fi

# Step 3: Buat Service Account untuk Vault
info "Step 3: Membuat Service Account untuk Vault..."
SERVICE_ACCOUNT_NAME="vault-sa"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Cek apakah service account sudah ada
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
    progress "Service account '$SERVICE_ACCOUNT_EMAIL' sudah ada"
else
    gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
        --display-name="Vault Auto-Unseal Service Account" \
        --project="$PROJECT_ID"
    progress "Service account '$SERVICE_ACCOUNT_EMAIL' berhasil dibuat"
fi

# Step 4: Bind role Cloud KMS CryptoKey Encrypter/Decrypter & Cloud KMS Viewer
info "Step 4: Memberikan role ke Service Account..."
ROLES=("roles/cloudkms.cryptoKeyEncrypterDecrypter" "roles/cloudkms.viewer")
KEY_RESOURCE="projects/${PROJECT_ID}/locations/${KEY_RING_LOCATION}/keyRings/${KEY_RING_NAME}/cryptoKeys/${CRYPTO_KEY_NAME}"

for KMS_ROLE in "${ROLES[@]}"; do
    # Check current IAM policy
    CURRENT_BINDING=$(gcloud kms keys get-iam-policy "$CRYPTO_KEY_NAME" \
        --keyring="$KEY_RING_NAME" \
        --location="$KEY_RING_LOCATION" \
        --project="$PROJECT_ID" \
        --format="json" 2>/dev/null | jq -r ".bindings[] | select(.role == \"$KMS_ROLE\") | .members[]" | grep "$SERVICE_ACCOUNT_EMAIL" || true)

    if [[ -n "$CURRENT_BINDING" ]]; then
        progress "Service account sudah memiliki role '$KMS_ROLE'"
    else
        gcloud kms keys add-iam-policy-binding "$CRYPTO_KEY_NAME" \
            --keyring="$KEY_RING_NAME" \
            --location="$KEY_RING_LOCATION" \
            --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
            --role="$KMS_ROLE" \
            --project="$PROJECT_ID"
        progress "Role '$KMS_ROLE' berhasil diberikan ke service account"
    fi
done

# Step 5: Verifikasi setup
info "Step 5: Memverifikasi setup..."
echo ""
echo "======================================================================="
echo "SETUP KMS UNTUK VAULT AUTO-UNSEAL BERHASIL!"
echo "======================================================================="
echo ""
echo "Detail konfigurasi:"
echo "  Project ID:       $PROJECT_ID"
echo "  Region:           $REGION"
echo "  Key Ring:         $KEY_RING_NAME"
echo "  Crypto Key:       $CRYPTO_KEY_NAME"
echo "  Service Account:  $SERVICE_ACCOUNT_EMAIL"
echo "  KMS Role:         $KMS_ROLE"
echo ""
echo "Resource path untuk Vault seal configuration:"
echo "  projects/${PROJECT_ID}/locations/${KEY_RING_LOCATION}/keyRings/${KEY_RING_NAME}/cryptoKeys/${CRYPTO_KEY_NAME}"
echo ""
echo "======================================================================="
echo "LANGKAH SELANJUTNYA untuk Workload Identity:"
echo "1. Annotate Kubernetes ServiceAccount 'vault' di namespace 'vault':"
echo "   kubectl annotate serviceaccount vault \\"
echo "     --namespace vault \\"
echo "     iam.gke.io/gcp-service-account=${SERVICE_ACCOUNT_EMAIL}"
echo ""
echo "2. Pastikan Workload Identity sudah aktif di GKE cluster:"
echo "   - Check di GCP Console: GKE → Cluster → Features → Workload Identity"
echo ""
echo "3. Untuk Vault Helm values, gunakan konfigurasi seal:"
echo "   seal \"gcpckms\" {"
echo "     project     = \"${PROJECT_ID}\""
echo "     region      = \"${REGION}\""
echo "     key_ring    = \"${KEY_RING_NAME}\""
echo "     crypto_key  = \"${CRYPTO_KEY_NAME}\""
echo "   }"
echo ""
echo "4. Di Vault Helm values, tambahkan annotation di serviceAccount:"
echo "   serviceAccount:"
echo "     annotations:"
echo "       iam.gke.io/gcp-service-account: \"${SERVICE_ACCOUNT_EMAIL}\""
echo ""
echo "======================================================================="

# Catatan untuk idempotensi
echo ""
echo "CATATAN:"
echo "  Script ini idempoten - bisa di-run multiple times tanpa error."
echo "  Jika resource sudah ada, script akan skip pembuatan."
echo ""
echo "Untuk menghapus (cleanup):"
echo "  # Hapus crypto key"
echo "  gcloud kms keys versions destroy 1 \\"
echo "    --key=${CRYPTO_KEY_NAME} \\"
echo "    --keyring=${KEY_RING_NAME} \\"
echo "    --location=${KEY_RING_LOCATION} \\"
echo "    --project=${PROJECT_ID}"
echo ""
echo "  # Hapus key ring (hanya jika sudah tidak ada key)"
echo "  gcloud kms keyrings delete ${KEY_RING_NAME} \\"
echo "    --location=${KEY_RING_LOCATION} \\"
echo "    --project=${PROJECT_ID}"
echo ""
echo "  # Hapus service account"
echo "  gcloud iam service-accounts delete ${SERVICE_ACCOUNT_EMAIL} \\"
echo "    --project=${PROJECT_ID}"
echo ""
echo "======================================================================="
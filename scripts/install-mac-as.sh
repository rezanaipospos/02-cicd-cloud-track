#!/usr/bin/env bash
# =============================================================================
# install-mac-as.sh — One-liner Installer untuk macOS (Apple Silicon & Intel)
# Be A DevOps Engineer: GCP Cloud Track
#
# Usage: ./scripts/install-mac-as.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_step() { echo -e "\n${BLUE}${BOLD}▶ $1${NC}"; }
log_ok()   { echo -e "  ${GREEN}✅ $1${NC}"; }
log_skip() { echo -e "  ${YELLOW}⏭  $1 (sudah ada — skip)${NC}"; }
log_fail() { echo -e "  ${RED}❌ ERROR: $1${NC}"; exit 1; }

# ─── Cek OS & Arsitektur ─────────────────────────────────────────────────────
if [[ "$OSTYPE" != "darwin"* ]]; then
  log_fail "Script ini hanya untuk macOS. Gunakan install-linux.sh untuk Linux / WSL2."
fi

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  ARCH_NAME="Apple Silicon (arm64 - M1/M2/M3/M4)"
  BREW_PREFIX="/opt/homebrew"
elif [ "$ARCH" = "x86_64" ]; then
  ARCH_NAME="Intel (x86_64)"
  BREW_PREFIX="/usr/local"
else
  log_fail "Arsitektur tidak didukung: $ARCH (hanya mendukung arm64 dan x86_64)"
fi

echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     Be A DevOps Engineer — GCP Cloud Track macOS Installer         ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Target: Mac $ARCH_NAME"
echo -e "  Tool yang akan diinstall:"
echo -e "  1. Homebrew"
echo -e "  2. Google Cloud SDK (gcloud CLI + gke-gcloud-auth-plugin)"
echo -e "  3. Terraform (HashiCorp)"
echo -e "  4. Terragrunt (Gruntwork)"
echo -e "  5. kubectl & Helm"
echo -e "  6. Kustomize"
echo -e "  7. Ansible"
echo -e "  8. ArgoCD CLI & kubectl argo-rollouts"
echo ""
read -r -p "  Lanjutkan instalasi otomatis? (y/N): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Dibatalkan."; exit 0; }

# ─── 1. Homebrew ─────────────────────────────────────────────────────────────
log_step "1/8 — Homebrew Package Manager"
if command -v brew &>/dev/null; then
  log_skip "Homebrew $(brew --version | head -1)"
else
  echo "  Menginstall Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [ -f "$BREW_PREFIX/bin/brew" ]; then
    SHELL_PROFILE="$HOME/.zprofile"
    if [ "${SHELL:-}" = "*/bash" ] || [ -f "$HOME/.bash_profile" ] && [ ! -f "$HOME/.zprofile" ]; then
      SHELL_PROFILE="$HOME/.bash_profile"
    fi
    echo "eval \"\$($BREW_PREFIX/bin/brew shellenv)\"" >> "$SHELL_PROFILE"
    eval "$($BREW_PREFIX/bin/brew shellenv)"
  fi
  log_ok "Homebrew terinstall"
fi

# ─── 2. Google Cloud SDK ─────────────────────────────────────────────────────
log_step "2/8 — Google Cloud SDK (gcloud CLI)"
if command -v gcloud &>/dev/null; then
  log_skip "gcloud $(gcloud version 2>/dev/null | head -1)"
else
  echo "  Menginstall google-cloud-sdk via brew..."
  brew install --cask google-cloud-sdk
  log_ok "Google Cloud SDK terinstall"
fi

# Pastikan auth plugin GKE terpasang
if gcloud components list 2>/dev/null | grep -q "gke-gcloud-auth-plugin.*Installed"; then
  log_skip "gke-gcloud-auth-plugin"
else
  echo "  Menginstall gke-gcloud-auth-plugin..."
  brew install gke-gcloud-auth-plugin || true
  log_ok "gke-gcloud-auth-plugin terinstall"
fi

# ─── 3. Terraform ────────────────────────────────────────────────────────────
log_step "3/8 — HashiCorp Terraform"
if command -v terraform &>/dev/null; then
  log_skip "Terraform $(terraform version | head -1)"
else
  echo "  Menginstall Terraform via brew..."
  brew tap hashiCorp/tap || true
  brew install hashicorp/tap/terraform || brew install terraform
  log_ok "Terraform terinstall"
fi

# ─── 4. Terragrunt ───────────────────────────────────────────────────────────
log_step "4/8 — Terragrunt"
if command -v terragrunt &>/dev/null; then
  log_skip "Terragrunt $(terragrunt --version | head -1)"
else
  echo "  Menginstall Terragrunt..."
  brew install terragrunt
  log_ok "Terragrunt terinstall"
fi

# ─── 5. kubectl & Helm ───────────────────────────────────────────────────────
log_step "5/8 — kubectl & Helm"
if command -v kubectl &>/dev/null; then
  log_skip "kubectl $(kubectl version --client -o yaml 2>/dev/null | grep gitVersion | head -1 || echo 'ready')"
else
  echo "  Menginstall kubectl..."
  brew install kubectl
  log_ok "kubectl terinstall"
fi

if command -v helm &>/dev/null; then
  log_skip "Helm $(helm version --short 2>/dev/null || echo 'ready')"
else
  echo "  Menginstall Helm..."
  brew install helm
  log_ok "Helm terinstall"
fi

# ─── 6. Kustomize ────────────────────────────────────────────────────────────
log_step "6/8 — Kustomize"
if command -v kustomize &>/dev/null; then
  log_skip "Kustomize $(kustomize version 2>/dev/null || echo 'ready')"
else
  echo "  Menginstall Kustomize..."
  brew install kustomize
  log_ok "Kustomize terinstall"
fi

# ─── 7. Ansible ──────────────────────────────────────────────────────────────
log_step "7/8 — Ansible"
if command -v ansible &>/dev/null; then
  log_skip "Ansible $(ansible --version | head -1)"
else
  echo "  Menginstall Ansible..."
  brew install ansible
  log_ok "Ansible terinstall"
fi

# ─── 8. ArgoCD CLI & Argo Rollouts Plugin ────────────────────────────────────
log_step "8/8 — ArgoCD CLI & kubectl argo-rollouts"
if command -v argocd &>/dev/null; then
  log_skip "ArgoCD CLI $(argocd version --client --short 2>/dev/null || echo 'ready')"
else
  echo "  Menginstall argocd..."
  brew install argocd
  log_ok "ArgoCD CLI terinstall"
fi

if kubectl argo rollouts version &>/dev/null; then
  log_skip "kubectl argo-rollouts plugin"
else
  echo "  Menginstall kubectl argo-rollouts via brew..."
  brew install argoproj/tap/kubectl-argo-rollouts || true
  log_ok "kubectl argo-rollouts plugin terinstall"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   🎉 SEMUA TOOLS CLOUD TRACK TELAH BERHASIL DIINSTALL DI MACOS!    ║${NC}"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Verifikasi cepat:"
echo -e "  • gcloud:     $(which gcloud || echo 'not found')"
echo -e "  • terraform:  $(which terraform || echo 'not found')"
echo -e "  • terragrunt: $(which terragrunt || echo 'not found')"
echo -e "  • kubectl:    $(which kubectl || echo 'not found')"
echo -e "  • helm:       $(which helm || echo 'not found')"
echo -e "  • kustomize:  $(which kustomize || echo 'not found')"
echo -e "  • ansible:    $(which ansible || echo 'not found')"
echo -e "  • argocd:     $(which argocd || echo 'not found')"
echo ""
echo -e "  Langkah berikutnya: Login ke akun GCP Anda:"
echo -e "  ${BOLD}gcloud auth login${NC}"
echo -e "  ${BOLD}gcloud auth application-default login${NC}"
echo ""

#!/usr/bin/env bash
set -euo pipefail

# Teardown stage 00-bootstrap.
# PERINGATAN: jalankan HANYA setelah seluruh stage lain sudah di-teardown,
# karena ini menghapus bucket state yang dipakai stage berikutnya.

cd "$(dirname "$0")"

echo ">> Menghancurkan resource stage 00-bootstrap..."
echo ">> Pastikan tidak ada stage lain yang masih memakai bucket state ini."

# force_destroy bucket = false, jadi bucket yang masih berisi state harus dikosongkan dulu.
terraform destroy "$@"

echo ">> Selesai. Verifikasi tidak ada resource yatim dengan: gcloud storage ls"

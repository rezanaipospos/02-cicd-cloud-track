# 04 — GKE Provisioning

**Prereq:** 00-bootstrap (state), 01-infra (jaringan). Disarankan setelah 03 untuk alur CI→CD.

## Tujuan
Provisioning cluster GKE via Terraform. Hemat biaya: Autopilot atau preemptible/spot node.

## Langkah
1. Isi variabel (`*.example`): cluster name, region, node config.
2. `terragrunt apply` / `terraform apply`.
3. `gcloud container clusters get-credentials ...`.

## Verifikasi
- `kubectl get nodes` menampilkan node siap.

## Teardown
- `./teardown.sh` — WAJIB dijalankan setelah selesai (resource termahal). Catatan biaya di sini.

> AD-9: kode spesifik GKE diisolasi agar varian kind (v2) bisa diselipkan.

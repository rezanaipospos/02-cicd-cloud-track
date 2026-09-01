# 06 — Secret Management (Vault)

**Prereq:** 05-gitops (cluster + GitOps + progressive delivery).

## Tujuan
Kelola secret aplikasi via Vault dengan pola aman untuk GitOps (tanpa secret plaintext di repo).

## Langkah
1. Install Vault ke cluster.
2. Konfigurasi auth + secret engine.
3. Integrasikan ke aplikasi (Vault Agent / External Secrets — final dipilih di sini).

## Verifikasi
- Tidak ada secret plaintext di repo GitOps; aplikasi memperoleh secret saat runtime.

## Teardown
Dikelola via GitOps + cluster.

> AD-5: secret tidak pernah di-commit.

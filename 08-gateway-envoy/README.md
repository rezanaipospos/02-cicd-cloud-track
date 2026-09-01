# 08 — Envoy Gateway

**Prereq:** 05-gitops (cluster + GitOps). Terkait 07 (SSO) bila mengekspos app terlindungi.

## Tujuan
Mengekspos aplikasi ke luar cluster: routing + TLS via Envoy Gateway.

## Langkah
1. Install Envoy Gateway.
2. Definisikan Gateway + routes untuk aplikasi.
3. Konfigurasi TLS.

## Verifikasi
- Aplikasi dapat diakses dari luar cluster lewat Envoy Gateway.

## Teardown
Dikelola via GitOps + cluster.

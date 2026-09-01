# 09 — Observability (New Relic + Golden Signals)

**Prereq:** aplikasi ter-deploy (05); idealnya setelah app berjalan.

## Tujuan
Instrumentasi mini backend/frontend ke New Relic dan membuat golden-signal alert sebagai kode via Terragrunt.

## Langkah
1. Instrumentasi aplikasi dengan agent New Relic.
2. Definisikan alert (latency, traffic, error, saturation) via Terragrunt.
3. Apply.

## Verifikasi
- Telemetry tampil di New Relic; alert golden signal terdefinisikan sebagai kode.

## Teardown
- `./teardown.sh` menghapus alert/resource Terragrunt.

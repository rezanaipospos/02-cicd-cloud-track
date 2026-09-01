# 10 — Capstone & Teardown

**Prereq:** seluruh stage 00–09.

## Tujuan
Membuktikan penguasaan alur penuh end-to-end.

## Definition of Done (FR-17) `[ASUMSI: konfirmasi]`
Peserta menjalankan berurutan tanpa intervensi manual di luar prosedur:
1. `commit` perubahan aplikasi.
2. CI Jenkins build/test (shared library).
3. GitOps (ArgoCD) sinkron ke cluster.
4. Canary deploy (Argo Rollouts).
5. Observability + golden-signal alert aktif (New Relic).
6. **Teardown bersih** seluruh resource cloud.

## Verifikasi
- Keenam tahap berhasil; tagihan GCP mendekati nol setelah teardown.

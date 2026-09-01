# 01 — Infra (Jaringan + VM Jenkins) — Terragrunt + Terraform

**Prereq:** 00-bootstrap (remote state siap, API aktif, SA Terraform tersedia).

## Tujuan
Provisioning jaringan + VM Jenkins memakai **Terraform modules** yang dirangkai **Terragrunt** dengan **state terpisah per component**.

## Kenapa Terragrunt (bukan satu root Terraform)
Masalah pada satu root monolitik:
- Ubah 1 komponen → `plan/apply` tetap men-scan SEMUA resource → lambat.
- Comment satu `module` block → Terraform menganggapnya "hapus" → **destroy berbahaya**.

Solusi di sini: setiap **component** punya state sendiri (di-generate Terragrunt), tapi tetap bisa di-apply sekaligus via `run-all`.

## Struktur

```
01-infra/
├── terragrunt.hcl                 # ROOT: generate backend.tf + provider.tf (state per-component)
├── modules/                       # Terraform murni, reusable
│   ├── network/                   # VPC + subnet + Cloud NAT + firewall IAP
│   └── compute/                   # VM Jenkins (tanpa IP publik, akses IAP)
└── environments/
    └── dev/
        ├── env.hcl                # Nilai per-env (project_id, region, zone, state_bucket, sa)
        ├── network/terragrunt.hcl # unit network (state sendiri)
        └── compute/terragrunt.hcl # unit compute (dependency → network)
```

## Cara pakai

1. Edit `environments/dev/env.hcl`: isi `project_id`, `region`, `zone`, `state_bucket` & `terraform_sa_email` (dari output stage 00).

**Apply semua sekaligus (urutan otomatis dari dependency):**
```bash
cd environments/dev
terragrunt run-all apply
```

**Apply / ubah SATU component saja (cepat, aman):**
```bash
cd environments/dev/compute
terragrunt apply        # hanya menyentuh state compute
```

**Tidak ingin sebuah component di-apply?** Cukup jangan jalankan folder-nya — TIDAK ada risiko destroy seperti saat meng-comment module di root monolitik.

## Verifikasi
- Format HCL: `terragrunt hclfmt --check` (dari `01-infra/`).
- Validasi modul: `cd modules/<m> && terraform init -backend=false && terraform validate`.
- Graph dependency: `cd environments/dev && terragrunt graph-dependencies` → `compute -> network`.
- VM via IAP: `gcloud compute ssh vm-jenkins-dev --tunnel-through-iap --zone <zone>`.

## Teardown
- Semua: `cd environments/dev && terragrunt run-all destroy`.
- Satu component: `cd environments/dev/<component> && terragrunt destroy`.

## Catatan biaya
- VM `e2-medium`: ~$25/bln saat running. Cloud NAT: ~$1/hari. VPC/subnet: gratis.

> **AD-9:** modul GCP-specific terpisah dari unit Terragrunt → varian Local track (kind) dapat diselipkan tanpa membongkar modul.

# Stage 01 — Infra: Network + Compute (Terragrunt)

**Tujuan:** provisioning VPC + Cloud NAT + firewall (IAP & webhook) + VM Jenkins (dengan IP publik untuk HAProxy).

## Variabel yang WAJIB diisi

Edit `course-project/01-infra/environments/dev/env.hcl`:

| Variabel | Dari mana | Contoh |
|----------|-----------|--------|
| `project_id` | Project GCP kamu | `"my-devops-course"` |
| `region` | Region pilihan | `"asia-southeast1"` |
| `zone` | Zone pilihan | `"asia-southeast1-a"` |
| `state_bucket` | Output stage 00: `state_bucket_name` | `"tf-state-my-devops-course"` |
| `terraform_sa_email` | Output stage 00: `terraform_service_account_email` | `"sa-terraform@my-devops-course.iam.gserviceaccount.com"` |

Opsional: edit `webhook_allowed_cidrs` di `environments/dev/network/terragrunt.hcl` untuk menambah IP admin kamu.

## Langkah

```bash
cd course-project/01-infra/environments/dev

# 1. Edit env.hcl — isi semua variabel dari tabel di atas
#    (gunakan output terraform dari stage 00)

# 2. Apply semua sekaligus (urutan otomatis: network → compute)
terragrunt run-all init
terragrunt run-all apply

# ATAU apply per-component (selektif):
# cd network && terragrunt init && terragrunt apply
# cd ../compute && terragrunt init && terragrunt apply
```

## Verifikasi
```bash
# VPC & subnet
gcloud compute networks list
gcloud compute networks subnets list --regions=asia-southeast1

# Firewall rules
gcloud compute firewall-rules list --filter="network:vpc-course-dev"

# VM Jenkins (harus punya IP publik + tag allow-iap-ssh, allow-webhook)
gcloud compute instances describe vm-jenkins-dev --zone=asia-southeast1-a --format="get(networkInterfaces[0].accessConfigs[0].natIP)"

# SSH via IAP (tetap bisa)
gcloud compute ssh vm-jenkins-dev --tunnel-through-iap --zone asia-southeast1-a
```

## Output penting (untuk stage berikutnya)
```bash
cd compute && terragrunt output instance_public_ip    # IP untuk DNS domain
cd compute && terragrunt output ssh_via_iap_command    # perintah SSH
```

## Atau apply per-component (selektif, lebih cepat)

```bash
# Network dulu
cd network
terragrunt init
terragrunt apply

# Lalu compute (bergantung pada network)
cd ../compute
terragrunt init
terragrunt apply
```

**Verifikasi:**
```bash
# Cek VPC & subnet
gcloud compute networks list
gcloud compute networks subnets list --regions=$(grep region env.hcl | awk -F'"' '{print $2}')

# SSH ke VM Jenkins via IAP
gcloud compute ssh vm-jenkins-dev --tunnel-through-iap --zone asia-southeast1-a
```

---

# Stage 01b — Artifact Registry (Terragrunt)

**Tujuan:** provisioning Google Artifact Registry untuk menyimpan Docker images dari CI pipeline Jenkins.

## Prasyarat
- Stage 00 applied (SA Terraform aktif)
- Stage 01 applied (env.hcl sudah diisi dengan project_id + region)

## Variabel yang WAJIB diisi

Edit `course-project/01-infra/environments/dev/artifact-registry/terragrunt.hcl`:

| Variabel | Dari mana | Contoh |
|----------|-----------|--------|
| `gke_node_sa_email` | Output GKE: `terragrunt output node_pool_sa_email` | `"sa-gke-node@PROJECT.iam.gserviceaccount.com"` |
| `jenkins_sa_email` | Opsional — SA Jenkins VM jika dedicated | `""` (kosong = skip IAM binding) |

> **Catatan:** Jika Jenkins menggunakan `gcloud auth configure-docker` dengan SA VM default, biarkan `jenkins_sa_email` kosong and tambahkan role `roles/artifactregistry.writer` ke SA VM lewat module compute.

## Langkah

```bash
cd course-project/01-infra/environments/dev/artifact-registry

# 1. Init
terragrunt init

# 2. Plan — review apa yang dibuat
terragrunt plan

# 3. Apply
terragrunt apply
```

## Output penting

```bash
terragrunt output registry_url
# Contoh output: asia-southeast1-docker.pkg.dev/nsr-devops/docker-images-repo
# Gunakan URL ini di pipeline.yaml (registry.region + registry.project_id + registry.repository)
```

## Verifikasi

```bash
# Cek repository terbuat
gcloud artifacts repositories list --location=asia-southeast1

# Cek IAM bindings
gcloud artifacts repositories get-iam-policy docker-images-repo \
  --location=asia-southeast1

# Test docker push (dari Jenkins VM atau lokal dengan gcloud auth)
gcloud auth configure-docker asia-southeast1-docker.pkg.dev
docker pull hello-world
docker tag hello-world asia-southeast1-docker.pkg.dev/YOUR_PROJECT/docker-images-repo/test:latest
docker push asia-southeast1-docker.pkg.dev/YOUR_PROJECT/docker-images-repo/test:latest
```

## Setup Docker auth di Jenkins VM

Setelah registry dibuat, Jenkins VM perlu konfigurasi docker credential:

```bash
# SSH ke Jenkins VM
gcloud compute ssh vm-jenkins-dev --tunnel-through-iap --zone=asia-southeast1-a

# Configure docker credential helper (pakai SA VM / ADC)
gcloud auth configure-docker asia-southeast1-docker.pkg.dev

# Verifikasi (dari dalam VM)
cat ~/.docker/config.json | grep asia-southeast1
```

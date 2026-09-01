# Stage 04 — GKE: Kubernetes Cluster (Terragrunt)

**Tujuan:** provisioning GKE cluster private + Workload Identity + node pool hemat biaya.

## Prasyarat
- Stage 01 applied (network + subnet dengan secondary ranges untuk pods/services)
- Stage 00 applied (SA Terraform punya `roles/container.admin`)

## Variabel yang dipakai

GKE menggunakan `env.hcl` yang sama dengan Stage 01 (sudah diisi). Konfigurasi spesifik GKE ada di Terragrunt inputs `environments/dev/gke/terragrunt.hcl`:

| Parameter | Default | Penjelasan |
|-----------|---------|------------|
| `cluster_name` | `gke-course-dev` | Nama cluster |
| `zone` | dari env.hcl | Zone cluster (zonal = lebih murah) |
| `machine_type` | `e2-medium` | Machine type node (~$25/bulan) |
| `min_node_count` | `1` | Minimum node (autoscaling) |
| `max_node_count` | `2` | Maximum node |
| `preemptible` | `true` | Spot/preemptible (60-91% lebih murah) |
| `disk_size_gb` | `30` | Disk per node |

## Langkah

```bash
cd course-project/01-infra/environments/dev/gke

# 1. Review konfigurasi (opsional — edit terragrunt.hcl jika perlu override)

# 2. Init & apply
terragrunt init
terragrunt apply

# 3. Dapatkan kubectl credentials
# (perintah ini juga ada di output)
gcloud container clusters get-credentials gke-course-dev \
  --zone asia-southeast1-a \
  --project YOUR_PROJECT_ID
```

## Verifikasi
```bash
# Cek cluster
gcloud container clusters list

# Cek nodes
kubectl get nodes

# Cek Workload Identity aktif
kubectl describe node | grep -i "iam.gke.io"

# Cek autoscaling
kubectl get nodes -o wide  # harus 1 node (min); akan scale ke 2 saat load naik
```

## ⚠️ Catatan biaya (KRITIS!)
GKE adalah **resource termahal** di course ini:
- e2-medium preemptible: ~$8/bulan per node
- e2-medium regular: ~$25/bulan per node
- Control plane (zonal): gratis (GKE free tier)
- **SELALU teardown jika tidak dipakai:** `cd gke && terragrunt destroy`

## Output penting
```bash
terragrunt output get_credentials_command   # perintah kubectl credentials
terragrunt output cluster_name              # nama cluster
terragrunt output node_pool_sa_email        # SA node (untuk Workload Identity binding)
```

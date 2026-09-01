# =============================================================================
# Module: network
# VPC custom-mode + subnet + Cloud Router + Cloud NAT + firewall IAP.
# Pola VPC biasa (bukan Shared VPC) — disederhanakan untuk course.
# =============================================================================

# --- VPC ---
resource "google_compute_network" "main" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false

  # ⚠️ PROTEKSI DESTROY: prevent_destroy hardcoded true (Pendekatan A).
  # Terraform TIDAK menerima variabel di lifecycle.prevent_destroy.
  # Untuk destroy: edit manual block ini (comment/hapus), lalu apply.
  # Lihat RUNBOOK untuk prosedur lengkap.
  lifecycle {
    prevent_destroy = true
  }
}

# --- Subnet ---
resource "google_compute_subnetwork" "main" {
  project                  = var.project_id
  name                     = var.subnet_name
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.main.id
  private_ip_google_access = true

  # Secondary ranges untuk GKE pods & services (Story 4.1)
  secondary_ip_range {
    range_name    = var.subnet_pods_range_name
    ip_cidr_range = var.subnet_pods_cidr
  }
  secondary_ip_range {
    range_name    = var.subnet_services_range_name
    ip_cidr_range = var.subnet_services_cidr
  }

  # ⚠️ PROTEKSI DESTROY (AD-18)
  lifecycle {
    prevent_destroy = true
  }
}

# --- Cloud Router (dibutuhkan oleh NAT) ---
resource "google_compute_router" "main" {
  project = var.project_id
  name    = var.router_name
  region  = var.region
  network = google_compute_network.main.id
}

# --- Reserved IP untuk Cloud NAT ---
resource "google_compute_address" "nat" {
  project = var.project_id
  name    = var.nat_ip_name
  region  = var.region
}

# --- Cloud NAT (egress tanpa IP publik pada instance) ---
resource "google_compute_router_nat" "main" {
  project = var.project_id
  name    = var.nat_name
  router  = google_compute_router.main.name
  region  = var.region

  # Menggunakan reserved static IP
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  # =========================================================================
  # Catatan Konfigurasi Production (Wajib di-enable di Production Setup):
  # =========================================================================
  # 1. Aktifkan Dynamic Port Allocation agar port diskalakan otomatis sesuai beban Node GKE:
  #    enable_dynamic_port_allocation = true
  #
  # 2. Tingkatkan nilai Minimum ports per VM instance ke 1024 atau lebih untuk mencegah SNAT port exhaustion:
  #    min_ports_per_vm = 1024
  # =========================================================================

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# --- Firewall: izinkan IAP SSH (35.235.240.0/20) ke tag "allow-iap-ssh" ---
resource "google_compute_firewall" "allow_iap_ssh" {
  project = var.project_id
  name    = var.firewall_iap_name
  network = google_compute_network.main.id

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Range resmi IAP untuk TCP forwarding
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["allow-iap-ssh"]
}

# --- Firewall: izinkan HTTPS (443) dari GitHub webhook IPs + admin ---
resource "google_compute_firewall" "allow_github_webhook" {
  project = var.project_id
  name    = var.firewall_webhook_name
  network = google_compute_network.main.id

  direction = "INGRESS"
  priority  = 900

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  # GitHub webhook IP ranges (https://api.github.com/meta -> hooks)
  # Ditambah IP admin untuk akses Jenkins UI via HTTPS
  source_ranges = var.webhook_allowed_cidrs
  target_tags   = ["allow-webhook"]
}

# --- Firewall: izinkan HTTP (80) dari anywhere (Let's Encrypt ACME challenge) ---
resource "google_compute_firewall" "allow_http_acme" {
  project = var.project_id
  name    = "allow-http-acme"
  network = google_compute_network.main.id

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  # Let's Encrypt validation datang dari IP yang tidak tetap — harus 0.0.0.0/0
  # HAProxy hanya meneruskan path /.well-known/acme-challenge/ ke certbot;
  # semua traffic lain di-redirect ke HTTPS (terlindungi whitelist di port 443).
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-webhook"]
}

# =============================================================================
# Private Service Access (PSA) untuk CloudSQL (Private IP)
# =============================================================================

# Alokasi IP range internal khusus untuk service Google
resource "google_compute_global_address" "private_ip_alloc" {
  project       = var.project_id
  name          = var.psa_range_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.main.id
}

# Peering VPC ke Service Networking (Google APIs)
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}

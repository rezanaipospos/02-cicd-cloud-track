# =============================================================================
# Module: gke
# GKE cluster private, production-grade:
# - Dataplane V2 (Cilium) → Network Policy otomatis
# - Workload Identity
# - Authorized networks (hanya IP tertentu bisa kubectl)
# - Shielded nodes
# - Max pods/node = 64 (hemat IP, cegah exhaustion)
# - Node pool: preemptible/spot, autoscaling, least-priv SA
# - Pub/Sub upgrade notifications
# - NodeLocal DNSCache
# - Cost allocation
# - Gateway API DISABLED (pakai Envoy Gateway sendiri di Epic 9)
# =============================================================================

locals {
  location = var.zone != "" ? var.zone : var.region
}

# --- Node pool Service Account (least privilege) ---
resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE node pool SA for ${var.cluster_name}"
}

resource "google_project_iam_member" "gke_nodes_roles" {
  for_each = toset([
    "roles/artifactregistry.reader",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# --- Pub/Sub topic for upgrade notifications ---
resource "google_pubsub_topic" "gke_upgrades" {
  project = var.project_id
  name    = var.upgrade_notifications_topic
}

# --- GKE Cluster ---
resource "google_container_cluster" "main" {
  project  = var.project_id
  name     = var.cluster_name
  location = local.location

  network    = var.network_self_link
  subnetwork = var.subnet_self_link

  # --- Dataplane V2 (Cilium) → Network Policy otomatis ---
  datapath_provider = "ADVANCED_DATAPATH"

  # --- Private cluster ---
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # --- Authorized networks (security: siapa yang boleh kubectl) ---
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_cidrs
      content {
        cidr_block   = cidr_blocks.value.cidr
        display_name = cidr_blocks.value.name
      }
    }
  }

  # --- IP allocation: secondary ranges ---
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # --- Max pods per node (cegah IP exhaustion) ---
  default_max_pods_per_node = var.max_pods_per_node

  # --- Release channel STABLE ---
  release_channel {
    channel = "STABLE"
  }

  # --- Gateway API DISABLED (pakai Envoy Gateway sendiri) ---
  # gateway_api_config { channel = "CHANNEL_DISABLED" }
  # Note: tidak men-set gateway_api_config = default disabled di GKE Standard

  # --- Workload Identity ---
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # --- Shielded nodes (integrity + secure boot) ---
  enable_shielded_nodes = true

  # --- Cost allocation ---
  cost_management_config {
    enabled = true
  }

  # --- Upgrade notifications via Pub/Sub ---
  notification_config {
    pubsub {
      enabled = true
      topic   = google_pubsub_topic.gke_upgrades.id
    }
  }

  # --- NodeLocal DNSCache ---
  addons_config {
    http_load_balancing {
      disabled = true # disabled karena pakai Envoy Gateway
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    dns_cache_config {
      enabled = true # NodeLocal DNSCache
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    network_policy_config {
      disabled = true # Dataplane V2 handles this natively
    }
  }

  # VPA
  vertical_pod_autoscaling {
    enabled = true
  }

  # Monitoring
  monitoring_config {
    managed_prometheus {
      enabled = false # pakai New Relic (Epic 7)
    }
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  # Logging (system + workload untuk debugging; configurable)
  logging_config {
    enable_components = var.logging_components
  }

  # Security posture
  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  # Hapus default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # Deletion protection (native GCP API-level)
  deletion_protection = var.enable_destroy_protection

  # ⚠️ PROTEKSI DESTROY (AD-18): GKE cluster stateful kritis.
  # Untuk destroy: comment block ini + set deletion_protection=false, lalu apply.
  lifecycle {
    prevent_destroy = true
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "02:00"
    }
  }
}

# --- Node Pool ---
resource "google_container_node_pool" "main" {
  project  = var.project_id
  name     = var.node_pool_name
  location = local.location
  cluster  = google_container_cluster.main.name

  max_pods_per_node = var.max_pods_per_node

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-standard"
    preemptible  = var.preemptible

    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = merge(var.labels, {
      cluster        = var.cluster_name
      provisioned_by = "terraform"
    })
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

# GKE Standard Cluster Module
# This module creates a cost-optimized, secure GKE Standard cluster
# with Workload Identity, private nodes, and security best practices.
# Optimized for demo environments with smaller boot disks to save quota.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# GKE Standard Cluster
resource "google_container_cluster" "primary" {
  provider = google
  project  = var.project_id
  name     = var.cluster_name
  location = var.regional_cluster ? var.region : var.zone

  # Standard GKE (not Autopilot) - allows zonal deployment and custom disk sizes
  # We remove the default node pool and create our own
  remove_default_node_pool = true
  initial_node_count       = 1

  # Network configuration
  network    = var.network_name
  subnetwork = var.subnetwork_name

  # IP allocation policy for pods and services
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private cluster configuration - no public IPs for nodes
  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block

    # Master authorized networks for API access
    master_global_access_config {
      enabled = true
    }
  }

  # Master authorized networks - control plane access
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  # Workload Identity for secure pod authentication
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Release channel for automatic updates
  release_channel {
    channel = var.release_channel
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_start_time
    }
  }

  # Addons configuration for Standard GKE
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  # Monitoring and logging
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]

    managed_prometheus {
      enabled = var.enable_managed_prometheus
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  # Resource labels
  resource_labels = merge(
    var.labels,
    {
      cluster-name = var.cluster_name
      mode         = "standard"
      managed-by   = "terraform"
    }
  )

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Description
  description = "GKE Standard cluster for observability demo - managed by Terraform"

  # Lifecycle configuration
  lifecycle {
    ignore_changes = [
      # Ignore node version changes as GKE auto-upgrades
      node_version,
    ]
  }

  timeouts {
    create = "45m"
    update = "60m"
    delete = "45m"
  }
}

# Node Pool for GKE Standard cluster
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.regional_cluster ? var.region : var.zone
  cluster    = google_container_cluster.primary.name
  project    = var.project_id

  # Node count configuration
  initial_node_count = var.regional_cluster ? 1 : 2  # 1 per zone if regional, 2 if zonal

  # Autoscaling configuration
  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }

  # Node management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Node configuration
  node_config {
    # Cost-optimized machine type for demo
    machine_type = "e2-standard-2"  # 2 vCPU, 8GB RAM

    # CRITICAL: Smaller boot disk to save quota (30GB instead of 100GB)
    disk_size_gb = 30
    disk_type    = "pd-standard"  # Standard persistent disk (cheaper than SSD)

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Labels
    labels = {
      env        = "demo"
      managed-by = "terraform"
    }

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Shielded instance config
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Tags for firewall rules
    tags = ["gke-node", var.cluster_name]
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  depends_on = [google_container_cluster.primary]
}

# Workload Identity binding for OpenTelemetry collector
resource "google_service_account_iam_member" "otel_workload_identity" {
  count = var.create_workload_identity_bindings && var.otel_service_account_email != "" ? 1 : 0

  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.otel_service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.otel_namespace}/${var.otel_service_account_name}]"

  depends_on = [google_container_cluster.primary]
}

# Workload Identity binding for microservices demo
resource "google_service_account_iam_member" "microservices_workload_identity" {
  count = var.create_workload_identity_bindings && var.microservices_service_account_email != "" ? 1 : 0

  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.microservices_service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.microservices_namespace}/${var.microservices_service_account_name}]"

  depends_on = [google_container_cluster.primary]
}

# Cloud DNS managed zone for GKE (optional, for custom domains)
resource "google_dns_managed_zone" "gke_zone" {
  count = var.create_dns_zone ? 1 : 0

  project     = var.project_id
  name        = "${var.cluster_name}-zone"
  dns_name    = "${var.dns_domain}."
  description = "DNS zone for GKE cluster ${var.cluster_name}"

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = var.network_self_link
    }
  }

  labels = var.labels
}

# Output cluster credentials to a kubeconfig file (optional)
locals {
  kubeconfig_template = var.generate_kubeconfig ? templatefile("${path.module}/templates/kubeconfig.tpl", {
    cluster_name     = google_container_cluster.primary.name
    cluster_endpoint = google_container_cluster.primary.endpoint
    cluster_ca       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
    project_id       = var.project_id
    region           = var.regional_cluster ? var.region : ""
    zone             = var.regional_cluster ? "" : var.zone
  }) : ""
}

# Write kubeconfig to file (if enabled)
resource "local_file" "kubeconfig" {
  count = var.generate_kubeconfig ? 1 : 0

  content  = local.kubeconfig_template
  filename = var.kubeconfig_path

  file_permission = "0600"
}

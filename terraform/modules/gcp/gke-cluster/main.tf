# GKE Autopilot Cluster Module
# This module creates a cost-optimized, secure GKE Autopilot cluster
# with Workload Identity, private nodes, and security best practices.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# GKE Autopilot Cluster
resource "google_container_cluster" "autopilot" {
  provider = google
  project  = var.project_id
  name     = var.cluster_name
  location = var.regional_cluster ? var.region : var.zone

  # Enable Autopilot mode for fully managed, cost-optimized cluster
  enable_autopilot = true

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

  # Cluster addons (limited options available for Autopilot)
  # Note: network_policy_config, dns_cache_config, and gcp_filestore_csi_driver_config
  # are not compatible with GKE Autopilot as they are managed automatically
  addons_config {
    # HTTP load balancing for Ingress
    http_load_balancing {
      disabled = false
    }

    # Horizontal Pod Autoscaling
    horizontal_pod_autoscaling {
      disabled = false
    }

    # GCE Persistent Disk CSI driver (supported in Autopilot)
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  # Binary Authorization (optional, for enhanced security)
  dynamic "binary_authorization" {
    for_each = var.enable_binary_authorization ? [1] : []
    content {
      evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
    }
  }

  # Note: network_policy block is not compatible with GKE Autopilot
  # Autopilot clusters automatically manage network policies

  # Vertical Pod Autoscaling
  vertical_pod_autoscaling {
    enabled = var.enable_vertical_pod_autoscaling
  }

  # Monitoring and logging configuration
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]

    managed_prometheus {
      enabled = var.enable_managed_prometheus
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  # Security posture and vulnerability scanning
  security_posture_config {
    mode               = var.enable_security_posture ? "BASIC" : "DISABLED"
    vulnerability_mode = var.enable_security_posture ? "VULNERABILITY_BASIC" : "VULNERABILITY_DISABLED"
  }

  # Resource labels
  resource_labels = merge(
    var.labels,
    {
      cluster-name = var.cluster_name
      mode         = "autopilot"
      managed-by   = "terraform"
    }
  )

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Description
  description = "GKE Autopilot cluster for observability demo - managed by Terraform"

  # Lifecycle configuration
  lifecycle {
    ignore_changes = [
      # Ignore node version changes as GKE auto-upgrades
      node_version,
      # Ignore monitoring config changes from GKE auto-updates
      monitoring_config,
    ]
  }

  # Wait for APIs to be enabled
  depends_on = [
    # Assumes project-setup module has enabled required APIs
  ]

  timeouts {
    create = "45m"
    update = "60m"
    delete = "45m"
  }
}

# Workload Identity binding for OpenTelemetry collector
resource "google_service_account_iam_member" "otel_workload_identity" {
  count = var.otel_service_account_email != null ? 1 : 0

  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.otel_service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.otel_namespace}/${var.otel_service_account_name}]"
}

# Workload Identity binding for microservices demo
resource "google_service_account_iam_member" "microservices_workload_identity" {
  count = var.microservices_service_account_email != null ? 1 : 0

  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.microservices_service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.microservices_namespace}/${var.microservices_service_account_name}]"
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
# This is typically done via CLI: gcloud container clusters get-credentials
# but can be useful for automation

locals {
  kubeconfig_template = var.generate_kubeconfig ? templatefile("${path.module}/templates/kubeconfig.tpl", {
    cluster_name     = google_container_cluster.autopilot.name
    cluster_endpoint = google_container_cluster.autopilot.endpoint
    cluster_ca       = google_container_cluster.autopilot.master_auth[0].cluster_ca_certificate
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

# GCP VPC Network Module
# This module creates a VPC network with subnets, Cloud NAT, and firewall rules
# optimized for private GKE clusters with secure connectivity.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Create VPC network
resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false # We'll create custom subnets
  routing_mode            = "REGIONAL"
  description             = "VPC network for observability demo infrastructure"

  # Enable flow logs at the network level
  # Individual subnets can override this setting
  delete_default_routes_on_create = false
}

# Create subnet for GKE cluster
resource "google_compute_subnetwork" "gke_subnet" {
  project = var.project_id
  name    = "${var.network_name}-gke-subnet"
  region  = var.region
  network = google_compute_network.vpc.id

  # Primary IP range for GKE nodes
  ip_cidr_range = var.gke_subnet_cidr

  # Secondary IP ranges for GKE pods and services
  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = var.gke_pods_cidr
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = var.gke_services_cidr
  }

  # Enable VPC flow logs for security and troubleshooting
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5 # Sample 50% of flows
    metadata             = "INCLUDE_ALL_METADATA"
  }

  # Enable private Google access for pulling images, accessing GCS, etc.
  private_ip_google_access = true

  description = "Subnet for GKE cluster nodes, pods, and services"
}

# Cloud Router for Cloud NAT
resource "google_compute_router" "router" {
  project = var.project_id
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id

  description = "Cloud Router for NAT gateway"

  bgp {
    asn = 64514 # Private ASN
  }
}

# Cloud NAT for outbound internet connectivity
# Allows private GKE nodes to pull images, access external APIs, etc.
resource "google_compute_router_nat" "nat" {
  project = var.project_id
  name    = "${var.network_name}-nat"
  region  = var.region
  router  = google_compute_router.router.name

  # Use AUTO_ONLY to automatically allocate IPs only for instances without external IPs
  nat_ip_allocate_option = "AUTO_ONLY"

  # Configure to NAT all subnet IP ranges
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  # Enable logging for troubleshooting
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  # Connection timeouts
  min_ports_per_vm                    = 64
  max_ports_per_vm                    = 512
  enable_endpoint_independent_mapping = true
}

# Firewall rule: Allow internal communication within VPC
resource "google_compute_firewall" "allow_internal" {
  project = var.project_id
  name    = "${var.network_name}-allow-internal"
  network = google_compute_network.vpc.name

  description = "Allow internal communication between all resources in VPC"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  # Allow from all internal subnets
  source_ranges = [
    var.gke_subnet_cidr,
    var.gke_pods_cidr,
    var.gke_services_cidr,
  ]

  priority = 1000
}

# Firewall rule: Allow health checks from Google Cloud
resource "google_compute_firewall" "allow_health_checks" {
  project = var.project_id
  name    = "${var.network_name}-allow-health-checks"
  network = google_compute_network.vpc.name

  description = "Allow health checks from Google Cloud load balancers"

  allow {
    protocol = "tcp"
  }

  # Google Cloud health check IP ranges
  source_ranges = [
    "35.191.0.0/16",  # Google Cloud health check ranges
    "130.211.0.0/22", # Legacy health check ranges
  ]

  priority = 1000
}

# Firewall rule: Allow IAP (Identity-Aware Proxy) access
resource "google_compute_firewall" "allow_iap" {
  project = var.project_id
  name    = "${var.network_name}-allow-iap"
  network = google_compute_network.vpc.name

  description = "Allow Identity-Aware Proxy (IAP) connections"

  allow {
    protocol = "tcp"
    ports    = ["22", "3389", "443"]
  }

  # IAP IP range
  source_ranges = ["35.235.240.0/20"]

  priority = 1000
}

# Firewall rule: Deny all ingress by default
resource "google_compute_firewall" "deny_all_ingress" {
  project = var.project_id
  name    = "${var.network_name}-deny-all-ingress"
  network = google_compute_network.vpc.name

  description = "Deny all ingress traffic by default (lowest priority)"

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]

  # Lowest priority - other rules override this
  priority = 65534
}

# Firewall rule: Allow specific egress (optional, can be customized)
resource "google_compute_firewall" "allow_egress" {
  project   = var.project_id
  name      = "${var.network_name}-allow-egress"
  network   = google_compute_network.vpc.name
  direction = "EGRESS"

  description = "Allow all egress traffic (can be customized for security)"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]

  priority = 1000
}

# Optional: Firewall rule for SSH access (disabled by default)
resource "google_compute_firewall" "allow_ssh" {
  count = var.enable_ssh_access ? 1 : 0

  project = var.project_id
  name    = "${var.network_name}-allow-ssh"
  network = google_compute_network.vpc.name

  description = "Allow SSH access from specified source ranges"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges

  priority = 1000
}

# Reserve static IP for load balancer (optional)
resource "google_compute_global_address" "ingress_ip" {
  count = var.create_static_ip ? 1 : 0

  project      = var.project_id
  name         = "${var.network_name}-ingress-ip"
  address_type = "EXTERNAL"
  description  = "Static IP for ingress load balancer"
}

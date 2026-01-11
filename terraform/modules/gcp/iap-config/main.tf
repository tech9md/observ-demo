# IAP (Identity-Aware Proxy) Configuration Module
# This module sets up Identity-Aware Proxy for secure, VPN-free access
# to applications using Google identity for authentication.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# IAP Brand (OAuth consent screen)
# Note: Only one brand can exist per project
resource "google_iap_brand" "project_brand" {
  count = var.create_brand ? 1 : 0

  project           = var.project_id
  application_title = var.application_title
  support_email     = var.support_email

  # Brand cannot be destroyed once created
  lifecycle {
    prevent_destroy = false # Set to true in production
  }
}

# IAP OAuth Client for web applications
resource "google_iap_client" "iap_client" {
  count = var.create_oauth_client ? 1 : 0

  display_name = var.oauth_client_name
  brand        = var.create_brand ? google_iap_brand.project_brand[0].name : var.existing_brand_name

  depends_on = [google_iap_brand.project_brand]
}

# Grant IAP access to specific users
resource "google_iap_web_iam_member" "iap_https_resource_accessor" {
  for_each = toset(var.iap_users)

  project = var.project_id
  role    = "roles/iap.httpsResourceAccessor"
  member  = each.value

  # Note: This grants access at the project level
  # For backend-specific access, use google_iap_web_backend_service_iam_member
}

# Backend service configuration for IAP
# This is typically created by GKE ingress, but we can reference it
data "google_compute_backend_service" "iap_backend" {
  for_each = toset(var.backend_service_names)

  project = var.project_id
  name    = each.value
}

# Grant IAP access to specific backend services
resource "google_iap_web_backend_service_iam_member" "backend_access" {
  for_each = {
    for pair in flatten([
      for backend in var.backend_service_names : [
        for user in var.iap_users : {
          backend = backend
          user    = user
          key     = "${backend}-${user}"
        }
      ]
    ]) : pair.key => pair
  }

  project             = var.project_id
  web_backend_service = each.value.backend
  role                = "roles/iap.httpsResourceAccessor"
  member              = each.value.user

  depends_on = [data.google_compute_backend_service.iap_backend]
}

# Service account for IAP tunnel (optional, for IAP TCP forwarding)
resource "google_service_account" "iap_tunnel" {
  count = var.create_tunnel_service_account ? 1 : 0

  project      = var.project_id
  account_id   = "iap-tunnel"
  display_name = "IAP Tunnel Service Account"
  description  = "Service account for IAP TCP forwarding"
}

# Grant IAP Tunnel User role
resource "google_project_iam_member" "iap_tunnel_user" {
  for_each = var.create_tunnel_service_account ? toset(var.iap_users) : toset([])

  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = each.value
}

# Firewall rule to allow IAP traffic
resource "google_compute_firewall" "allow_iap" {
  count = var.create_firewall_rule ? 1 : 0

  project = var.project_id
  name    = "${var.network_name}-allow-iap-ingress"
  network = var.network_name

  description = "Allow ingress from IAP"

  allow {
    protocol = "tcp"
    ports    = var.allowed_ports
  }

  # IAP IP range
  source_ranges = ["35.235.240.0/20"]

  target_tags = var.target_tags

  priority = 1000
}

# Static IP address for IAP-enabled load balancer
resource "google_compute_global_address" "iap_lb_ip" {
  count = var.create_static_ip ? 1 : 0

  project      = var.project_id
  name         = "${var.name_prefix}-iap-lb-ip"
  address_type = "EXTERNAL"
  description  = "Static IP for IAP-enabled load balancer"
}

# SSL certificate for HTTPS (self-managed)
resource "google_compute_managed_ssl_certificate" "iap_cert" {
  count = var.create_ssl_certificate && length(var.domains) > 0 ? 1 : 0

  project = var.project_id
  name    = "${var.name_prefix}-iap-cert"

  managed {
    domains = var.domains
  }

  lifecycle {
    create_before_destroy = true
  }
}

# URL map for load balancer (example - typically created by Ingress)
# This is optional and mainly for reference
resource "google_compute_url_map" "iap_url_map" {
  count = var.create_url_map ? 1 : 0

  project         = var.project_id
  name            = "${var.name_prefix}-iap-url-map"
  default_service = var.default_backend_service

  description = "URL map for IAP-enabled services"
}

# HTTPS proxy
resource "google_compute_target_https_proxy" "iap_https_proxy" {
  count = var.create_https_proxy ? 1 : 0

  project = var.project_id
  name    = "${var.name_prefix}-iap-https-proxy"
  url_map = var.create_url_map ? google_compute_url_map.iap_url_map[0].id : var.url_map_id

  ssl_certificates = var.create_ssl_certificate ? [google_compute_managed_ssl_certificate.iap_cert[0].id] : var.ssl_certificate_ids

  description = "HTTPS proxy for IAP"
}

# Global forwarding rule
resource "google_compute_global_forwarding_rule" "iap_https" {
  count = var.create_forwarding_rule ? 1 : 0

  project    = var.project_id
  name       = "${var.name_prefix}-iap-https-rule"
  target     = google_compute_target_https_proxy.iap_https_proxy[0].id
  port_range = "443"
  ip_address = var.create_static_ip ? google_compute_global_address.iap_lb_ip[0].address : null

  load_balancing_scheme = "EXTERNAL_MANAGED"

  description = "Forwarding rule for IAP HTTPS traffic"
}

# Cloud Armor security policy (optional, for DDoS protection)
resource "google_compute_security_policy" "iap_policy" {
  count = var.create_security_policy ? 1 : 0

  project = var.project_id
  name    = "${var.name_prefix}-iap-policy"

  description = "Security policy for IAP-enabled services"

  # Default rule - allow all
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule"
  }

  # Rate limiting rule (optional)
  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      action   = "rate_based_ban"
      priority = 1000
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = ["*"]
        }
      }
      rate_limit_options {
        conform_action = "allow"
        exceed_action  = "deny(429)"
        enforce_on_key = "IP"
        rate_limit_threshold {
          count        = var.rate_limit_threshold
          interval_sec = 60
        }
        ban_duration_sec = 600 # Ban for 10 minutes
      }
      description = "Rate limiting rule"
    }
  }

  # Geo-blocking rule (optional)
  dynamic "rule" {
    for_each = length(var.blocked_regions) > 0 ? [1] : []
    content {
      action   = "deny(403)"
      priority = 900
      match {
        expr {
          expression = "origin.region_code in [${join(", ", formatlist("'%s'", var.blocked_regions))}]"
        }
      }
      description = "Block specific regions"
    }
  }
}

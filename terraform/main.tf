# GCP Observability Demo - Root Module
# This module orchestrates all infrastructure components for the observability demo platform

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  # Backend configuration (uncomment after initial setup)
  # backend "gcs" {
  #   bucket = "REPLACE_WITH_STATE_BUCKET_NAME"
  #   prefix = "terraform/state"
  # }
}

# Provider configuration
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Local variables for common configuration
locals {
  # Common labels applied to all resources
  common_labels = merge(
    var.labels,
    {
      project     = "observability-demo"
      managed-by  = "terraform"
      environment = var.environment
    }
  )

  # Network configuration
  network_name    = "${var.project_id}-vpc"
  subnet_name     = "${var.project_id}-gke-subnet"

  # GKE configuration
  cluster_name    = var.cluster_name != "" ? var.cluster_name : "${var.project_id}-gke"

  # Service account names
  otel_sa_name           = "otel-collector"
  microservices_sa_name  = "microservices-app"

  # Kubernetes namespaces
  otel_namespace          = "opentelemetry"
  microservices_namespace = "microservices-demo"
}

# Phase 1: Project Setup - Foundation (APIs, Service Accounts, State Bucket)
module "project_setup" {
  source = "./modules/gcp/project-setup"

  project_id         = var.project_id
  billing_account    = var.billing_account
  region             = var.region
  state_bucket_name  = var.state_bucket_name

  # Service accounts
  otel_service_account_name          = local.otel_sa_name
  microservices_service_account_name = local.microservices_sa_name

  # Enable optional features
  enable_cloud_trace      = var.enable_cloud_trace
  enable_cloud_monitoring = var.enable_cloud_monitoring
  enable_cloud_logging    = var.enable_cloud_logging

  labels = local.common_labels
}

# Phase 2: VPC Network - Networking Infrastructure
module "vpc_network" {
  source = "./modules/gcp/vpc-network"

  project_id   = var.project_id
  region       = var.region
  network_name = local.network_name

  # Subnet configuration
  subnet_name        = local.subnet_name
  subnet_cidr        = var.subnet_cidr
  pods_cidr          = var.pods_cidr
  services_cidr      = var.services_cidr
  pods_range_name    = "gke-pods"
  services_range_name = "gke-services"

  # Network features
  enable_flow_logs   = var.enable_flow_logs
  create_static_ip   = var.create_static_ip
  enable_ssh_access  = var.enable_ssh_access

  labels = local.common_labels

  depends_on = [module.project_setup]
}

# Phase 3: GKE Cluster - Kubernetes Infrastructure
module "gke_cluster" {
  source = "./modules/gcp/gke-cluster"

  project_id   = var.project_id
  region       = var.region
  zone         = var.zone
  cluster_name = local.cluster_name

  # Network configuration
  network_name         = module.vpc_network.network_name
  network_self_link    = module.vpc_network.network_self_link
  subnetwork_name      = module.vpc_network.gke_subnet_name
  pods_range_name      = module.vpc_network.gke_pods_range_name
  services_range_name  = module.vpc_network.gke_services_range_name

  # Cluster configuration
  regional_cluster               = var.regional_cluster
  enable_private_nodes           = var.enable_private_nodes
  enable_private_endpoint        = var.enable_private_endpoint
  master_ipv4_cidr_block         = var.master_ipv4_cidr_block
  master_authorized_networks     = var.master_authorized_networks

  # Features
  release_channel                    = var.release_channel
  enable_binary_authorization        = var.enable_binary_authorization
  enable_vertical_pod_autoscaling    = var.enable_vertical_pod_autoscaling
  enable_managed_prometheus          = var.enable_managed_prometheus
  enable_security_posture            = var.enable_security_posture
  deletion_protection                = var.deletion_protection

  # Workload Identity bindings
  otel_service_account_email          = module.project_setup.otel_service_account_email
  otel_namespace                      = local.otel_namespace
  otel_service_account_name           = "otel-collector-sa"

  microservices_service_account_email = module.project_setup.microservices_service_account_email
  microservices_namespace             = local.microservices_namespace
  microservices_service_account_name  = "microservices-sa"

  # DNS (optional)
  create_dns_zone     = var.create_dns_zone
  dns_domain          = var.dns_domain
  generate_kubeconfig = var.generate_kubeconfig
  kubeconfig_path     = var.kubeconfig_path

  labels = local.common_labels

  depends_on = [module.vpc_network]
}

# Phase 4: IAP Configuration - Secure Access (Optional)
module "iap_config" {
  source = "./modules/gcp/iap-config"
  count  = var.enable_iap ? 1 : 0

  project_id = var.project_id
  region     = var.region

  # IAP configuration
  iap_brand_name      = var.iap_brand_name
  create_brand        = var.create_iap_brand
  existing_brand_name = var.existing_iap_brand_name
  create_oauth_client = var.create_oauth_client
  iap_users           = var.iap_users

  # Backend services for IAP
  backend_service_names = var.iap_backend_services

  # Network resources
  network_name       = module.vpc_network.network_name
  create_static_ip   = var.create_iap_static_ip
  static_ip_name     = "${local.cluster_name}-iap-ip"

  # SSL configuration
  create_ssl_certificate = var.create_ssl_certificate
  domains                = var.ssl_domains
  certificate_name       = "${local.cluster_name}-ssl-cert"

  # Load balancer configuration
  create_url_map         = var.create_url_map
  url_map_id             = var.url_map_id
  create_https_proxy     = var.create_https_proxy
  create_forwarding_rule = var.create_forwarding_rule

  # Security features
  create_security_policy = var.create_security_policy
  enable_rate_limiting   = var.enable_rate_limiting
  rate_limit_threshold   = var.rate_limit_threshold
  allowed_countries      = var.allowed_countries
  blocked_countries      = var.blocked_countries

  # Firewall
  create_firewall_rule = var.create_iap_firewall

  # Tunnel service account (for SSH/RDP via IAP)
  create_tunnel_service_account = var.create_iap_tunnel_sa

  labels = local.common_labels

  depends_on = [module.gke_cluster]
}

# Phase 5: Monitoring - Alerts and Dashboards
module "monitoring" {
  source = "./modules/gcp/monitoring"

  project_id   = var.project_id
  region       = var.region
  cluster_name = local.cluster_name

  # Notification channels
  notification_email   = var.notification_email
  notification_slack   = var.notification_slack
  notification_pagerduty = var.notification_pagerduty

  # Alert configuration
  enable_cluster_health_alerts = var.enable_cluster_health_alerts
  enable_pod_alerts            = var.enable_pod_alerts
  enable_error_rate_alerts     = var.enable_error_rate_alerts
  enable_resource_alerts       = var.enable_resource_alerts
  enable_deployment_alerts     = var.enable_deployment_alerts

  # Alert thresholds
  cpu_threshold_percent    = var.cpu_threshold_percent
  memory_threshold_percent = var.memory_threshold_percent
  error_rate_threshold     = var.error_rate_threshold

  # Dashboard configuration
  create_overview_dashboard = var.create_overview_dashboard
  create_gke_dashboard      = var.create_gke_dashboard
  dashboard_name_prefix     = "${local.cluster_name}"

  # Uptime checks (optional)
  create_uptime_checks = var.create_uptime_checks
  uptime_check_urls    = var.uptime_check_urls

  labels = local.common_labels

  depends_on = [module.gke_cluster]
}

# Phase 6: Budget Alerts - Cost Monitoring
module "budget_alerts" {
  source = "./modules/gcp/budget-alerts"

  project_id      = var.project_id
  billing_account = var.billing_account

  # Budget configuration
  budget_amount   = var.budget_amount
  currency_code   = var.currency_code
  calendar_period = var.calendar_period

  # Threshold rules
  threshold_rules = var.budget_threshold_rules

  # Notifications
  notification_email = var.notification_email
  notification_slack = var.notification_slack

  # Pub/Sub configuration
  create_pubsub_subscription = var.create_budget_subscription

  # Alert function (optional)
  create_alert_function = var.create_budget_alert_function

  # Monitoring integration
  create_monitoring_alert = var.create_budget_monitoring_alert
  alert_threshold_percent = var.budget_alert_threshold

  # Cost metric (optional)
  create_cost_metric = var.create_cost_metric

  labels = local.common_labels

  depends_on = [module.project_setup]
}

# Kubernetes provider configuration (after cluster creation)
data "google_client_config" "default" {
  depends_on = [module.gke_cluster]
}

data "google_container_cluster" "primary" {
  name     = local.cluster_name
  location = var.regional_cluster ? var.region : var.zone
  project  = var.project_id

  depends_on = [module.gke_cluster]
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.primary.endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes {
    host  = "https://${data.google_container_cluster.primary.endpoint}"
    token = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate
    )
  }
}

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
  network_name = "${var.project_id}-vpc"
  subnet_name  = "${var.project_id}-gke-subnet"

  # GKE configuration
  cluster_name = var.cluster_name != "" ? var.cluster_name : "${var.project_id}-gke"

  # Service account names
  otel_sa_name          = "otel-collector"
  microservices_sa_name = "microservices-app"

  # Kubernetes namespaces
  otel_namespace          = "opentelemetry"
  microservices_namespace = "microservices-demo"
}

# Phase 1: Project Setup - Foundation (APIs, Service Accounts, State Bucket)
module "project_setup" {
  source = "./modules/gcp/project-setup"

  project_id        = var.project_id
  billing_account   = var.billing_account
  region            = var.region
  state_bucket_name = var.state_bucket_name
  environment       = var.environment

  # Skip bucket creation when state_bucket_name is empty (using existing bucket)
  create_state_bucket = var.state_bucket_name != ""

  # Enable workload identity service accounts
  create_workload_identities = true

  labels = local.common_labels
}

# Phase 2: VPC Network - Networking Infrastructure
module "vpc_network" {
  source = "./modules/gcp/vpc-network"

  project_id   = var.project_id
  region       = var.region
  network_name = local.network_name

  # Subnet configuration (use module's variable names)
  gke_subnet_cidr   = var.subnet_cidr
  gke_pods_cidr     = var.pods_cidr
  gke_services_cidr = var.services_cidr

  # Network features
  enable_flow_logs  = var.enable_flow_logs
  create_static_ip  = var.create_static_ip
  enable_ssh_access = var.enable_ssh_access

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
  network_name        = module.vpc_network.network_name
  network_self_link   = module.vpc_network.network_self_link
  subnetwork_name     = module.vpc_network.gke_subnet_name
  pods_range_name     = module.vpc_network.gke_pods_range_name
  services_range_name = module.vpc_network.gke_services_range_name

  # Cluster configuration
  regional_cluster           = var.regional_cluster
  enable_private_nodes       = var.enable_private_nodes
  enable_private_endpoint    = var.enable_private_endpoint
  master_ipv4_cidr_block     = var.master_ipv4_cidr_block
  master_authorized_networks = var.master_authorized_networks

  # Features
  release_channel                 = var.release_channel
  enable_binary_authorization     = var.enable_binary_authorization
  enable_vertical_pod_autoscaling = var.enable_vertical_pod_autoscaling
  enable_managed_prometheus       = var.enable_managed_prometheus
  enable_security_posture         = var.enable_security_posture
  deletion_protection             = var.deletion_protection

  # Workload Identity bindings
  otel_service_account_email = module.project_setup.otel_service_account_email
  otel_namespace             = local.otel_namespace
  otel_service_account_name  = "otel-collector-sa"

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

  # IAP configuration (use module's variable names)
  application_title   = var.iap_brand_name
  support_email       = var.iap_support_email != "" ? var.iap_support_email : var.notification_email
  create_brand        = var.create_iap_brand
  existing_brand_name = var.existing_iap_brand_name
  create_oauth_client = var.create_oauth_client
  iap_users           = var.iap_users

  # Backend services for IAP
  backend_service_names = var.iap_backend_services

  # Network resources
  network_name     = module.vpc_network.network_name
  create_static_ip = var.create_iap_static_ip

  # SSL configuration
  create_ssl_certificate = var.create_ssl_certificate
  domains                = var.ssl_domains

  # Load balancer configuration
  create_url_map         = var.create_url_map
  url_map_id             = var.url_map_id
  create_https_proxy     = var.create_https_proxy
  create_forwarding_rule = var.create_forwarding_rule

  # Security features
  create_security_policy = var.create_security_policy
  enable_rate_limiting   = var.enable_rate_limiting
  rate_limit_threshold   = var.rate_limit_threshold
  blocked_regions        = var.blocked_countries

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
  cluster_name = local.cluster_name

  # Notification channels (use module's variable names)
  notification_emails   = var.notification_email != "" ? [var.notification_email] : []
  slack_webhook_url     = var.notification_slack
  pagerduty_service_key = var.notification_pagerduty

  # Alert configuration (use module's variable names)
  enable_gke_alerts        = var.enable_cluster_health_alerts
  enable_pod_alerts        = var.enable_pod_alerts
  enable_error_alerts      = var.enable_error_rate_alerts
  enable_resource_alerts   = var.enable_resource_alerts
  enable_deployment_alerts = var.enable_deployment_alerts
  enable_lb_alerts         = var.enable_lb_alerts

  # Alert thresholds (module uses absolute values, not percentages)
  cpu_threshold          = var.cpu_threshold_percent / 100         # Convert to cores (0.8 = 80%)
  memory_threshold_bytes = var.memory_threshold_percent * 21474836 # ~2GB at 100%
  error_rate_threshold   = var.error_rate_threshold

  # Dashboard configuration
  create_gke_dashboard = var.create_gke_dashboard

  # Uptime checks (optional) - module uses single host/path not URLs
  create_uptime_checks = var.create_uptime_checks
  uptime_check_host    = length(var.uptime_check_urls) > 0 ? var.uptime_check_urls[0] : ""

  labels = local.common_labels

  depends_on = [module.gke_cluster]
}

# Phase 6: Budget Alerts - Cost Monitoring
module "budget_alerts" {
  source = "./modules/gcp/budget-alerts"

  project_id      = var.project_id
  billing_account = var.billing_account
  region          = var.region

  # Budget configuration
  budget_name     = var.budget_name
  budget_amount   = var.budget_amount
  currency_code   = var.currency_code
  calendar_period = var.calendar_period

  # Threshold rules (using module's default if not specified)
  threshold_rules = var.budget_threshold_rules

  # Notifications - use monitoring notification channels from monitoring module
  monitoring_notification_channels = var.notification_email != "" ? module.monitoring.notification_channel_ids : []

  # Pub/Sub configuration
  create_pubsub_subscription = var.create_budget_subscription

  # Alert function (optional)
  create_alert_function = var.create_budget_alert_function

  # Monitoring integration
  create_monitoring_alert = var.create_budget_monitoring_alert

  # Cost metric (optional)
  create_cost_metric = var.create_cost_metric

  labels = local.common_labels

  depends_on = [module.project_setup, module.monitoring]
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

# GCP Observability Demo - Root Module Variables
# User-facing variables for complete stack deployment

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "project_id" {
  description = "GCP project ID"
  type        = string

  validation {
    condition     = can(regex("^[a-z][-a-z0-9]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "billing_account" {
  description = "GCP billing account ID (format: XXXXXX-XXXXXX-XXXXXX)"
  type        = string

  validation {
    condition     = can(regex("^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$", var.billing_account))
    error_message = "Billing account must be in format: XXXXXX-XXXXXX-XXXXXX"
  }
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "Region must be a valid GCP region (e.g., us-central1, europe-west1)."
  }
}

# =============================================================================
# PROJECT CONFIGURATION
# =============================================================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "demo"

  validation {
    condition     = contains(["dev", "staging", "prod", "demo"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, demo."
  }
}

variable "labels" {
  description = "Additional labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "state_bucket_name" {
  description = "Name of the GCS bucket for Terraform state (must be globally unique)"
  type        = string
  default     = ""
}

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================

variable "subnet_cidr" {
  description = "CIDR range for GKE node subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "CIDR range for GKE pods"
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_cidr" {
  description = "CIDR range for GKE services"
  type        = string
  default     = "10.8.0.0/20"
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = false
}

variable "create_static_ip" {
  description = "Create static IP for load balancer"
  type        = bool
  default     = true
}

variable "enable_ssh_access" {
  description = "Enable SSH access via firewall (for debugging)"
  type        = bool
  default     = false
}

# =============================================================================
# GKE CLUSTER CONFIGURATION
# =============================================================================

variable "cluster_name" {
  description = "Name of the GKE cluster (defaults to PROJECT_ID-gke)"
  type        = string
  default     = ""
}

variable "zone" {
  description = "GCP zone for zonal cluster (if regional_cluster = false)"
  type        = string
  default     = "us-central1-a"
}

variable "regional_cluster" {
  description = "Create a regional cluster (true) or zonal cluster (false)"
  type        = bool
  default     = true
}

variable "enable_private_nodes" {
  description = "Enable private IP addresses for cluster nodes"
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "Enable private cluster endpoint (requires Cloud VPN or interconnect)"
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "IP range for GKE master nodes"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "CIDR blocks allowed to access GKE master"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "release_channel" {
  description = "GKE release channel (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "Release channel must be one of: RAPID, REGULAR, STABLE."
  }
}

variable "enable_binary_authorization" {
  description = "Enable Binary Authorization for enhanced security"
  type        = bool
  default     = false
}

variable "enable_vertical_pod_autoscaling" {
  description = "Enable Vertical Pod Autoscaling"
  type        = bool
  default     = true
}

variable "enable_managed_prometheus" {
  description = "Enable GKE-managed Prometheus"
  type        = bool
  default     = true
}

variable "enable_security_posture" {
  description = "Enable security posture scanning"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Prevent accidental cluster deletion"
  type        = bool
  default     = false
}

variable "create_dns_zone" {
  description = "Create private DNS zone for cluster"
  type        = bool
  default     = false
}

variable "dns_domain" {
  description = "DNS domain for the cluster (required if create_dns_zone = true)"
  type        = string
  default     = "observ-demo.internal"
}

variable "generate_kubeconfig" {
  description = "Generate kubeconfig file"
  type        = bool
  default     = false
}

variable "kubeconfig_path" {
  description = "Path to write kubeconfig file"
  type        = string
  default     = "~/.kube/observ-demo-config"
}

# =============================================================================
# IAP (IDENTITY-AWARE PROXY) CONFIGURATION
# =============================================================================

variable "enable_iap" {
  description = "Enable Identity-Aware Proxy for secure access"
  type        = bool
  default     = true
}

variable "iap_brand_name" {
  description = "Name for the IAP OAuth consent screen"
  type        = string
  default     = "Observability Demo"
}

variable "iap_support_email" {
  description = "Support email for IAP OAuth consent screen (falls back to notification_email if empty)"
  type        = string
  default     = ""
}

variable "create_iap_brand" {
  description = "Create new IAP brand (OAuth consent screen). Requires valid support_email."
  type        = bool
  default     = false # Disabled by default - requires OAuth consent screen setup
}

variable "existing_iap_brand_name" {
  description = "Existing IAP brand name (if create_iap_brand = false)"
  type        = string
  default     = null
}

variable "create_oauth_client" {
  description = "Create OAuth client for IAP. Requires IAP brand to exist."
  type        = bool
  default     = false # Disabled by default - requires IAP brand
}

variable "iap_users" {
  description = "List of users allowed to access via IAP (format: user:email@example.com)"
  type        = list(string)
  default     = []
}

variable "iap_backend_services" {
  description = "List of backend service names to protect with IAP"
  type        = list(string)
  default     = []
}

variable "create_iap_static_ip" {
  description = "Create static IP for IAP load balancer"
  type        = bool
  default     = true
}

variable "create_ssl_certificate" {
  description = "Create managed SSL certificate"
  type        = bool
  default     = false
}

variable "ssl_domains" {
  description = "Domains for SSL certificate (required if create_ssl_certificate = true)"
  type        = list(string)
  default     = []
}

variable "create_url_map" {
  description = "Create URL map for load balancer"
  type        = bool
  default     = false
}

variable "url_map_id" {
  description = "Existing URL map ID (if create_url_map = false)"
  type        = string
  default     = null
}

variable "create_https_proxy" {
  description = "Create HTTPS proxy"
  type        = bool
  default     = false
}

variable "create_forwarding_rule" {
  description = "Create forwarding rule"
  type        = bool
  default     = false
}

variable "create_security_policy" {
  description = "Create Cloud Armor security policy"
  type        = bool
  default     = true
}

variable "enable_rate_limiting" {
  description = "Enable rate limiting in security policy"
  type        = bool
  default     = true
}

variable "rate_limit_threshold" {
  description = "Rate limit threshold (requests per minute)"
  type        = number
  default     = 1000
}

variable "allowed_countries" {
  description = "List of allowed country codes (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

variable "blocked_countries" {
  description = "List of blocked country codes (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

variable "create_iap_firewall" {
  description = "Create firewall rule for IAP access"
  type        = bool
  default     = true
}

variable "create_iap_tunnel_sa" {
  description = "Create service account for IAP tunnel (SSH/RDP)"
  type        = bool
  default     = false
}

# =============================================================================
# MONITORING & ALERTING CONFIGURATION
# =============================================================================

variable "notification_email" {
  description = "Email address for notifications"
  type        = string
  default     = ""
}

variable "notification_slack" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "notification_pagerduty" {
  description = "PagerDuty integration key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_cluster_health_alerts" {
  description = "Enable GKE cluster health alerts (requires running cluster)"
  type        = bool
  default     = false
}

variable "enable_pod_alerts" {
  description = "Enable pod-level alerts (requires running cluster)"
  type        = bool
  default     = false
}

variable "enable_error_rate_alerts" {
  description = "Enable error rate alerts (requires running cluster)"
  type        = bool
  default     = false
}

variable "enable_resource_alerts" {
  description = "Enable resource usage alerts (requires running cluster)"
  type        = bool
  default     = false
}

variable "enable_deployment_alerts" {
  description = "Enable deployment failure alerts (requires running cluster)"
  type        = bool
  default     = false
}

variable "enable_lb_alerts" {
  description = "Enable load balancer alerts (requires load balancer)"
  type        = bool
  default     = false
}

variable "cpu_threshold_percent" {
  description = "CPU usage threshold for alerts (percent)"
  type        = number
  default     = 80

  validation {
    condition     = var.cpu_threshold_percent > 0 && var.cpu_threshold_percent <= 100
    error_message = "CPU threshold must be between 1 and 100."
  }
}

variable "memory_threshold_percent" {
  description = "Memory usage threshold for alerts (percent)"
  type        = number
  default     = 85

  validation {
    condition     = var.memory_threshold_percent > 0 && var.memory_threshold_percent <= 100
    error_message = "Memory threshold must be between 1 and 100."
  }
}

variable "error_rate_threshold" {
  description = "Error rate threshold for alerts (errors per second)"
  type        = number
  default     = 5
}

variable "create_overview_dashboard" {
  description = "Create overview dashboard"
  type        = bool
  default     = true
}

variable "create_gke_dashboard" {
  description = "Create GKE-specific dashboard (requires running cluster)"
  type        = bool
  default     = false
}

variable "create_uptime_checks" {
  description = "Create uptime checks for services"
  type        = bool
  default     = false
}

variable "uptime_check_urls" {
  description = "URLs to monitor with uptime checks"
  type        = list(string)
  default     = []
}

# =============================================================================
# BUDGET & COST CONFIGURATION
# =============================================================================

variable "budget_name" {
  description = "Name of the budget"
  type        = string
  default     = "observ-demo-budget"
}

variable "budget_amount" {
  description = "Monthly budget amount"
  type        = number
  default     = 100

  validation {
    condition     = var.budget_amount > 0
    error_message = "Budget amount must be greater than 0."
  }
}

variable "currency_code" {
  description = "Currency code for budget (ISO 4217)"
  type        = string
  default     = "USD"

  validation {
    condition     = contains(["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "INR"], var.currency_code)
    error_message = "Currency must be one of: USD, EUR, GBP, CAD, AUD, JPY, INR."
  }
}

variable "calendar_period" {
  description = "Budget calendar period (MONTH, QUARTER, YEAR)"
  type        = string
  default     = "MONTH"

  validation {
    condition     = contains(["MONTH", "QUARTER", "YEAR"], var.calendar_period)
    error_message = "Calendar period must be one of: MONTH, QUARTER, YEAR."
  }
}

variable "budget_threshold_rules" {
  description = "Budget threshold alert rules"
  type = list(object({
    threshold_percent = number
    spend_basis       = string
  }))
  default = [
    { threshold_percent = 0.5, spend_basis = "CURRENT_SPEND" },
    { threshold_percent = 0.75, spend_basis = "CURRENT_SPEND" },
    { threshold_percent = 0.9, spend_basis = "CURRENT_SPEND" },
    { threshold_percent = 1.0, spend_basis = "CURRENT_SPEND" },
    { threshold_percent = 1.0, spend_basis = "FORECASTED_SPEND" }
  ]
}

variable "enable_budget_alerts" {
  description = "Enable budget alerts module. Requires valid billing_account."
  type        = bool
  default     = false # Disabled by default - requires valid billing account
}

variable "create_budget_subscription" {
  description = "Create Pub/Sub subscription for budget alerts"
  type        = bool
  default     = false
}

variable "create_budget_alert_function" {
  description = "Create Cloud Function for custom budget alert handling"
  type        = bool
  default     = false
}

variable "create_budget_monitoring_alert" {
  description = "Create Cloud Monitoring alert for budget exceeded"
  type        = bool
  default     = false # Disabled by default - billing metrics may not be available
}

variable "budget_alert_threshold" {
  description = "Budget threshold for monitoring alert (percent)"
  type        = number
  default     = 90

  validation {
    condition     = var.budget_alert_threshold > 0 && var.budget_alert_threshold <= 100
    error_message = "Budget alert threshold must be between 1 and 100."
  }
}

variable "create_cost_metric" {
  description = "Create custom log-based metric for cost tracking"
  type        = bool
  default     = false
}

# =============================================================================
# FEATURE FLAGS
# =============================================================================

variable "enable_cloud_trace" {
  description = "Enable Cloud Trace API"
  type        = bool
  default     = true
}

variable "enable_cloud_monitoring" {
  description = "Enable Cloud Monitoring API"
  type        = bool
  default     = true
}

variable "enable_cloud_logging" {
  description = "Enable Cloud Logging API"
  type        = bool
  default     = true
}

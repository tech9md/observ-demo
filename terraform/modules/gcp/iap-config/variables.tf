# Variables for IAP Configuration Module

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "observ-demo"
}

# IAP Brand configuration
variable "create_brand" {
  description = "Create IAP brand (OAuth consent screen). Only one brand per project."
  type        = bool
  default     = true
}

variable "existing_brand_name" {
  description = "Name of existing IAP brand (if create_brand is false)"
  type        = string
  default     = ""
}

variable "application_title" {
  description = "Application title for OAuth consent screen"
  type        = string
  default     = "Observability Demo"
}

variable "support_email" {
  description = "Support email for OAuth consent screen (required when create_brand = true)"
  type        = string
  default     = ""

  validation {
    condition     = var.support_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.support_email))
    error_message = "Support email must be empty or a valid email address."
  }
}

# OAuth Client configuration
variable "create_oauth_client" {
  description = "Create OAuth client for IAP"
  type        = bool
  default     = true
}

variable "oauth_client_name" {
  description = "Display name for OAuth client"
  type        = string
  default     = "IAP Client"
}

# IAP access control
variable "iap_users" {
  description = "List of users/groups/service accounts granted IAP access (user:email, group:email, serviceAccount:email)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for user in var.iap_users :
      can(regex("^(user|group|serviceAccount|domain):", user))
    ])
    error_message = "IAP users must be in format: user:email, group:email, serviceAccount:email, or domain:domain.com"
  }
}

# Backend services
variable "backend_service_names" {
  description = "List of backend service names to configure IAP for"
  type        = list(string)
  default     = []
}

# Network configuration
variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = ""
}

variable "create_firewall_rule" {
  description = "Create firewall rule to allow IAP traffic"
  type        = bool
  default     = true
}

variable "allowed_ports" {
  description = "Ports to allow through IAP firewall"
  type        = list(string)
  default     = ["22", "3389", "443", "80"]
}

variable "target_tags" {
  description = "Network tags for IAP firewall rule targets"
  type        = list(string)
  default     = []
}

# IAP Tunnel (for SSH/RDP via IAP)
variable "create_tunnel_service_account" {
  description = "Create service account for IAP tunnel"
  type        = bool
  default     = false
}

# Load balancer configuration
variable "create_static_ip" {
  description = "Create static IP address for load balancer"
  type        = bool
  default     = true
}

variable "create_ssl_certificate" {
  description = "Create managed SSL certificate"
  type        = bool
  default     = false # Set to true if using custom domains
}

variable "domains" {
  description = "Domains for SSL certificate"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for domain in var.domains :
      can(regex("^[a-z0-9][a-z0-9-\\.]*[a-z0-9]$", domain))
    ])
    error_message = "Domains must be valid DNS names."
  }
}

variable "ssl_certificate_ids" {
  description = "IDs of existing SSL certificates (if not creating new ones)"
  type        = list(string)
  default     = []
}

# URL Map and Proxy configuration
variable "create_url_map" {
  description = "Create URL map (typically created by GKE Ingress)"
  type        = bool
  default     = false
}

variable "url_map_id" {
  description = "ID of existing URL map (if not creating new one)"
  type        = string
  default     = ""
}

variable "default_backend_service" {
  description = "Default backend service for URL map"
  type        = string
  default     = ""
}

variable "create_https_proxy" {
  description = "Create HTTPS proxy"
  type        = bool
  default     = false
}

variable "create_forwarding_rule" {
  description = "Create global forwarding rule"
  type        = bool
  default     = false
}

# Cloud Armor security policy
variable "create_security_policy" {
  description = "Create Cloud Armor security policy"
  type        = bool
  default     = false
}

variable "enable_rate_limiting" {
  description = "Enable rate limiting in security policy"
  type        = bool
  default     = true
}

variable "rate_limit_threshold" {
  description = "Maximum requests per minute per IP"
  type        = number
  default     = 100

  validation {
    condition     = var.rate_limit_threshold > 0 && var.rate_limit_threshold <= 10000
    error_message = "Rate limit threshold must be between 1 and 10000."
  }
}

variable "blocked_regions" {
  description = "List of region codes to block (e.g., ['CN', 'RU'])"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for region in var.blocked_regions :
      length(region) == 2 && upper(region) == region
    ])
    error_message = "Region codes must be 2-letter uppercase codes (e.g., 'US', 'CN')."
  }
}

# Labels
variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default = {
    managed-by = "terraform"
    component  = "iap"
  }
}

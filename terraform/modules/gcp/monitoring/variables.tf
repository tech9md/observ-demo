# Variables for Cloud Monitoring Module

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster to monitor"
  type        = string
  default     = "observ-demo-cluster"
}

# Notification configuration
variable "notification_emails" {
  description = "List of email addresses for alert notifications"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.notification_emails :
      can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All notification emails must be valid email addresses."
  }
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "slack_channel_name" {
  description = "Slack channel name for notifications"
  type        = string
  default     = "#alerts"
}

variable "pagerduty_service_key" {
  description = "PagerDuty service integration key"
  type        = string
  default     = ""
  sensitive   = true
}

# Alert toggles
variable "enable_gke_alerts" {
  description = "Enable GKE cluster health alerts. Requires cluster to be running."
  type        = bool
  default     = false # Disabled by default - metric requires running cluster
}

variable "enable_pod_alerts" {
  description = "Enable pod-level alerts (crash loops, etc.). Requires cluster to be running."
  type        = bool
  default     = false # Disabled by default - metric requires running cluster
}

variable "enable_error_alerts" {
  description = "Enable application error rate alerts. Requires cluster to be running."
  type        = bool
  default     = false # Disabled by default - metric requires running cluster
}

variable "enable_resource_alerts" {
  description = "Enable resource usage alerts (CPU, memory). Requires cluster to be running."
  type        = bool
  default     = false # Disabled by default - metric requires running cluster
}

variable "enable_deployment_alerts" {
  description = "Enable deployment failure alerts. Requires cluster to be running."
  type        = bool
  default     = false # Disabled by default - metric requires running cluster
}

variable "enable_lb_alerts" {
  description = "Enable load balancer alerts"
  type        = bool
  default     = false # Disabled by default - requires load balancer
}

# Alert thresholds
variable "error_rate_threshold" {
  description = "Error log entries per second threshold"
  type        = number
  default     = 10

  validation {
    condition     = var.error_rate_threshold > 0
    error_message = "Error rate threshold must be greater than 0."
  }
}

variable "cpu_threshold" {
  description = "CPU usage threshold (cores)"
  type        = number
  default     = 0.8 # 80% of 1 core

  validation {
    condition     = var.cpu_threshold > 0
    error_message = "CPU threshold must be greater than 0."
  }
}

variable "memory_threshold_bytes" {
  description = "Memory usage threshold in bytes"
  type        = number
  default     = 2147483648 # 2GB

  validation {
    condition     = var.memory_threshold_bytes > 0
    error_message = "Memory threshold must be greater than 0."
  }
}

variable "lb_error_threshold" {
  description = "Load balancer 5xx errors per second threshold"
  type        = number
  default     = 5

  validation {
    condition     = var.lb_error_threshold > 0
    error_message = "LB error threshold must be greater than 0."
  }
}

# Dashboard configuration
variable "create_gke_dashboard" {
  description = "Create GKE metrics dashboard. Requires cluster to be running."
  type        = bool
  default     = false # Disabled by default - requires running cluster with metrics
}

# Uptime checks
variable "create_uptime_checks" {
  description = "Create uptime checks for applications"
  type        = bool
  default     = false # Enable when applications are deployed
}

variable "uptime_check_host" {
  description = "Host for uptime check"
  type        = string
  default     = ""
}

variable "uptime_check_path" {
  description = "Path for uptime check"
  type        = string
  default     = "/"
}

variable "uptime_check_content" {
  description = "Expected content in uptime check response"
  type        = string
  default     = "ok"
}

# Labels
variable "labels" {
  description = "Labels to apply to monitoring resources"
  type        = map(string)
  default = {
    managed-by = "terraform"
    component  = "monitoring"
  }
}

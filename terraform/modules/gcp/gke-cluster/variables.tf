# Variables for GKE Cluster Module

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "observ-demo-cluster"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,39}$", var.cluster_name))
    error_message = "Cluster name must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens (max 40 characters)."
  }
}

variable "region" {
  description = "The GCP region for the cluster"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for zonal cluster (ignored if regional_cluster is true)"
  type        = string
  default     = "us-central1-a"
}

variable "regional_cluster" {
  description = "Create a regional cluster (true) or zonal cluster (false)"
  type        = bool
  default     = true # Regional for high availability
}

# Network configuration
variable "network_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "network_self_link" {
  description = "Self-link of the VPC network"
  type        = string
}

variable "subnetwork_name" {
  description = "Name of the subnetwork"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the secondary IP range for pods"
  type        = string
  default     = "gke-pods"
}

variable "services_range_name" {
  description = "Name of the secondary IP range for services"
  type        = string
  default     = "gke-services"
}

# Private cluster configuration
variable "enable_private_nodes" {
  description = "Enable private nodes (no external IPs)"
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "Enable private endpoint (control plane not accessible from public internet)"
  type        = bool
  default     = false # Keep false to allow gcloud access
}

variable "master_ipv4_cidr_block" {
  description = "IPv4 CIDR block for the master network"
  type        = string
  default     = "172.16.0.0/28" # /28 provides 16 IPs

  validation {
    condition     = can(cidrhost(var.master_ipv4_cidr_block, 0))
    error_message = "Master IPv4 CIDR block must be a valid CIDR."
  }
}

variable "master_authorized_networks" {
  description = "List of authorized networks that can access the cluster control plane"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
  # Example:
  # [
  #   {
  #     cidr_block   = "10.0.0.0/8"
  #     display_name = "Internal network"
  #   }
  # ]
}

# Release channel and maintenance
variable "release_channel" {
  description = "GKE release channel (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "UNSPECIFIED"], var.release_channel)
    error_message = "Release channel must be RAPID, REGULAR, STABLE, or UNSPECIFIED."
  }
}

variable "maintenance_start_time" {
  description = "Start time for daily maintenance window (HH:MM format in UTC)"
  type        = string
  default     = "03:00" # 3 AM UTC

  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_start_time))
    error_message = "Maintenance start time must be in HH:MM format (00:00 to 23:59)."
  }
}

# Feature flags
variable "enable_vertical_pod_autoscaling" {
  description = "Enable Vertical Pod Autoscaling"
  type        = bool
  default     = true
}

variable "enable_managed_prometheus" {
  description = "Enable Google Cloud Managed Service for Prometheus"
  type        = bool
  default     = true
}

variable "enable_binary_authorization" {
  description = "Enable Binary Authorization for container image validation"
  type        = bool
  default     = false # Can be enabled for enhanced security
}

variable "enable_security_posture" {
  description = "Enable GKE security posture and vulnerability scanning"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection for the cluster"
  type        = bool
  default     = false # Set to true in production
}

# Workload Identity configuration
variable "create_workload_identity_bindings" {
  description = "Create Workload Identity bindings for service accounts (must be known at plan time)"
  type        = bool
  default     = true
}

variable "otel_service_account_email" {
  description = "Email of the GCP service account for OpenTelemetry collector"
  type        = string
  default     = ""
}

variable "otel_namespace" {
  description = "Kubernetes namespace for OpenTelemetry"
  type        = string
  default     = "otel-demo"
}

variable "otel_service_account_name" {
  description = "Kubernetes service account name for OpenTelemetry"
  type        = string
  default     = "otel-collector"
}

variable "microservices_service_account_email" {
  description = "Email of the GCP service account for microservices demo"
  type        = string
  default     = ""
}

variable "microservices_namespace" {
  description = "Kubernetes namespace for microservices demo"
  type        = string
  default     = "microservices-demo"
}

variable "microservices_service_account_name" {
  description = "Kubernetes service account name for microservices demo"
  type        = string
  default     = "microservices-demo"
}

# DNS configuration
variable "create_dns_zone" {
  description = "Create a private Cloud DNS zone for the cluster"
  type        = bool
  default     = false
}

variable "dns_domain" {
  description = "DNS domain for the private zone"
  type        = string
  default     = "observ-demo.internal"
}

# Kubeconfig generation
variable "generate_kubeconfig" {
  description = "Generate a kubeconfig file for cluster access"
  type        = bool
  default     = false # Typically use gcloud instead
}

variable "kubeconfig_path" {
  description = "Path to write the kubeconfig file"
  type        = string
  default     = "./kubeconfig"
}

# Labels
variable "labels" {
  description = "Labels to apply to the cluster and resources"
  type        = map(string)
  default = {
    managed-by = "terraform"
    component  = "gke-cluster"
  }
}

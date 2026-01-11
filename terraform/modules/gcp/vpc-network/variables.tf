# Variables for VPC Network Module

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for regional resources"
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "observ-demo-vpc"

  validation {
    condition     = can(regex("^[a-z][-a-z0-9]{0,62}$", var.network_name))
    error_message = "Network name must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens (max 63 characters)."
  }
}

variable "gke_subnet_cidr" {
  description = "CIDR range for GKE nodes subnet"
  type        = string
  default     = "10.0.0.0/20" # Supports 4,096 IPs (4,091 usable)

  validation {
    condition     = can(cidrhost(var.gke_subnet_cidr, 0))
    error_message = "GKE subnet CIDR must be a valid CIDR block."
  }
}

variable "gke_pods_cidr" {
  description = "Secondary CIDR range for GKE pods"
  type        = string
  default     = "10.4.0.0/14" # Supports 262,144 IPs for pods

  validation {
    condition     = can(cidrhost(var.gke_pods_cidr, 0))
    error_message = "GKE pods CIDR must be a valid CIDR block."
  }
}

variable "gke_services_cidr" {
  description = "Secondary CIDR range for GKE services"
  type        = string
  default     = "10.8.0.0/20" # Supports 4,096 IPs for services

  validation {
    condition     = can(cidrhost(var.gke_services_cidr, 0))
    error_message = "GKE services CIDR must be a valid CIDR block."
  }
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs for the subnet"
  type        = bool
  default     = true
}

variable "flow_logs_sampling" {
  description = "Sampling rate for flow logs (0.0 to 1.0)"
  type        = number
  default     = 0.5 # Sample 50% of flows for cost optimization

  validation {
    condition     = var.flow_logs_sampling >= 0.0 && var.flow_logs_sampling <= 1.0
    error_message = "Flow logs sampling must be between 0.0 and 1.0."
  }
}

variable "enable_ssh_access" {
  description = "Enable SSH access firewall rule"
  type        = bool
  default     = false # Disabled by default for security
}

variable "ssh_source_ranges" {
  description = "Source IP ranges allowed for SSH access (if enabled)"
  type        = list(string)
  default     = ["35.235.240.0/20"] # IAP range by default

  validation {
    condition     = alltrue([for cidr in var.ssh_source_ranges : can(cidrhost(cidr, 0))])
    error_message = "All SSH source ranges must be valid CIDR blocks."
  }
}

variable "create_static_ip" {
  description = "Create a static external IP address for load balancer"
  type        = bool
  default     = false # Can be enabled if static IP is needed
}

variable "nat_min_ports_per_vm" {
  description = "Minimum number of ports allocated to each VM for Cloud NAT"
  type        = number
  default     = 64

  validation {
    condition     = var.nat_min_ports_per_vm >= 64 && var.nat_min_ports_per_vm <= 65536
    error_message = "NAT min ports per VM must be between 64 and 65536."
  }
}

variable "nat_max_ports_per_vm" {
  description = "Maximum number of ports allocated to each VM for Cloud NAT"
  type        = number
  default     = 512

  validation {
    condition     = var.nat_max_ports_per_vm >= 64 && var.nat_max_ports_per_vm <= 65536
    error_message = "NAT max ports per VM must be between 64 and 65536."
  }
}

variable "labels" {
  description = "Labels to apply to network resources"
  type        = map(string)
  default = {
    managed-by = "terraform"
    component  = "networking"
  }
}

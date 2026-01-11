# Variables for GCP Project Setup Module

variable "project_id" {
  description = "The GCP project ID"
  type        = string

  validation {
    condition     = can(regex("^[a-z][-a-z0-9]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must start with a lowercase letter, contain only lowercase letters, numbers, and hyphens, and be 6-30 characters long."
  }
}

variable "region" {
  description = "The primary GCP region for resources"
  type        = string
  default     = "us-central1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "Region must be a valid GCP region format (e.g., us-central1)."
  }
}

variable "state_bucket_name" {
  description = "Name of the GCS bucket for Terraform state"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-_.]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "Bucket name must be 3-63 characters, start and end with a lowercase letter or number, and contain only lowercase letters, numbers, hyphens, underscores, and periods."
  }
}

variable "state_prefix" {
  description = "Prefix for Terraform state files in the bucket"
  type        = string
  default     = "terraform/state"
}

variable "enable_versioning" {
  description = "Enable versioning for the Terraform state bucket"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "create_workload_identities" {
  description = "Create service accounts for workload identity (OpenTelemetry, Microservices)"
  type        = bool
  default     = true
}

variable "billing_account" {
  description = "The GCP billing account ID (optional, for budget setup)"
  type        = string
  default     = ""

  validation {
    condition     = var.billing_account == "" || can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", var.billing_account))
    error_message = "Billing account must be in format: 012345-6789AB-CDEF01 or empty string."
  }
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    managed-by = "terraform"
    project    = "observability-demo"
  }
}

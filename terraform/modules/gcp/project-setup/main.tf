# GCP Project Setup Module
# This module configures the foundational infrastructure for the observability demo
# including API enablement, service accounts, and Terraform state management.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Enable required GCP APIs
locals {
  required_apis = [
    "compute.googleapis.com",              # Compute Engine API
    "container.googleapis.com",            # Kubernetes Engine API
    "cloudresourcemanager.googleapis.com", # Cloud Resource Manager API
    "iam.googleapis.com",                  # IAM API
    "logging.googleapis.com",              # Cloud Logging API
    "monitoring.googleapis.com",           # Cloud Monitoring API
    "cloudtrace.googleapis.com",           # Cloud Trace API
    "servicenetworking.googleapis.com",    # Service Networking API
    "storage.googleapis.com",              # Cloud Storage API
    "secretmanager.googleapis.com",        # Secret Manager API
    "cloudbilling.googleapis.com",         # Cloud Billing API
    "iap.googleapis.com",                  # Identity-Aware Proxy API
  ]
}

resource "google_project_service" "required_apis" {
  for_each = toset(local.required_apis)

  project = var.project_id
  service = each.value

  # Don't disable the service if this resource is destroyed
  disable_on_destroy = false

  # Don't fail if the service is already enabled
  disable_dependent_services = false

  timeouts {
    create = "30m"
    update = "40m"
  }
}

# Create Terraform service account
resource "google_service_account" "terraform" {
  project      = var.project_id
  account_id   = "terraform-automation"
  display_name = "Terraform Automation Service Account"
  description  = "Service account for Terraform automation with minimal permissions"

  depends_on = [google_project_service.required_apis]
}

# Grant necessary IAM roles to Terraform service account
locals {
  terraform_roles = [
    "roles/compute.networkAdmin",            # VPC management
    "roles/container.admin",                 # GKE management
    "roles/iam.serviceAccountAdmin",         # Service account creation
    "roles/iam.serviceAccountUser",          # Service account impersonation
    "roles/resourcemanager.projectIamAdmin", # IAM management
    "roles/storage.admin",                   # GCS for state and artifacts
    "roles/monitoring.admin",                # Cloud Monitoring
    "roles/logging.admin",                   # Cloud Logging
  ]
}

resource "google_project_iam_member" "terraform_roles" {
  for_each = toset(local.terraform_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform.email}"

  depends_on = [google_service_account.terraform]
}

# Create GCS bucket for Terraform state (optional - skip if using existing bucket)
resource "google_storage_bucket" "terraform_state" {
  count = var.create_state_bucket && var.state_bucket_name != "" ? 1 : 0

  project  = var.project_id
  name     = var.state_bucket_name
  location = var.region

  # Enable versioning for state file recovery
  versioning {
    enabled = var.enable_versioning
  }

  # Lifecycle rule to keep last N versions
  lifecycle_rule {
    condition {
      num_newer_versions = 5
    }
    action {
      type = "Delete"
    }
  }

  # Enable uniform bucket-level access
  uniform_bucket_level_access = true

  # Note: Google-managed encryption is used by default when no encryption block is specified

  # Labels for organization
  labels = {
    purpose     = "terraform-state"
    managed-by  = "terraform"
    environment = var.environment
  }

  # Force destroy only in non-production environments
  force_destroy = var.environment != "prod"

  depends_on = [google_project_service.required_apis]
}

# Grant Terraform SA access to state bucket (only if bucket is created)
resource "google_storage_bucket_iam_member" "terraform_state_admin" {
  count = var.create_state_bucket && var.state_bucket_name != "" ? 1 : 0

  bucket = google_storage_bucket.terraform_state[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.terraform.email}"

  depends_on = [
    google_storage_bucket.terraform_state,
    google_service_account.terraform,
  ]
}

# Create state directory marker (only if bucket is created)
resource "google_storage_bucket_object" "state_directory" {
  count = var.create_state_bucket && var.state_bucket_name != "" ? 1 : 0

  bucket  = google_storage_bucket.terraform_state[0].name
  name    = "${var.state_prefix}/.keep"
  content = "Terraform state directory"

  depends_on = [google_storage_bucket.terraform_state]
}

# Create service account for OpenTelemetry collector
resource "google_service_account" "otel_collector" {
  count = var.create_workload_identities ? 1 : 0

  project      = var.project_id
  account_id   = "otel-collector"
  display_name = "OpenTelemetry Collector Service Account"
  description  = "Service account for OpenTelemetry collector with observability permissions"

  depends_on = [google_project_service.required_apis]
}

# Grant OpenTelemetry SA necessary permissions
locals {
  otel_roles = [
    "roles/cloudtrace.agent",        # Cloud Trace write
    "roles/monitoring.metricWriter", # Cloud Monitoring write
    "roles/logging.logWriter",       # Cloud Logging write
  ]
}

resource "google_project_iam_member" "otel_roles" {
  for_each = var.create_workload_identities ? toset(local.otel_roles) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.otel_collector[0].email}"

  depends_on = [google_service_account.otel_collector]
}

# Create service account for microservices demo
resource "google_service_account" "microservices_demo" {
  count = var.create_workload_identities ? 1 : 0

  project      = var.project_id
  account_id   = "microservices-demo"
  display_name = "Microservices Demo Service Account"
  description  = "Service account for Google Microservices Demo application"

  depends_on = [google_project_service.required_apis]
}

# Grant Microservices Demo SA necessary permissions
resource "google_project_iam_member" "microservices_roles" {
  for_each = var.create_workload_identities ? toset([
    "roles/cloudtrace.agent",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
  ]) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.microservices_demo[0].email}"

  depends_on = [google_service_account.microservices_demo]
}

# Note: Outputs are defined in outputs.tf

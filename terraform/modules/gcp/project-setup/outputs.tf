# Outputs for GCP Project Setup Module

output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "The primary GCP region"
  value       = var.region
}

output "terraform_service_account_email" {
  description = "Email address of the Terraform service account"
  value       = google_service_account.terraform.email
}

output "terraform_service_account_id" {
  description = "The service account ID for Terraform"
  value       = google_service_account.terraform.id
}

output "terraform_service_account_name" {
  description = "The fully-qualified name of the Terraform service account"
  value       = google_service_account.terraform.name
}

output "state_bucket_name" {
  description = "Name of the GCS bucket for Terraform state"
  value       = var.create_state_bucket && var.state_bucket_name != "" ? google_storage_bucket.terraform_state[0].name : var.state_bucket_name
}

output "state_bucket_url" {
  description = "URL of the Terraform state bucket"
  value       = var.create_state_bucket && var.state_bucket_name != "" ? google_storage_bucket.terraform_state[0].url : null
}

output "state_bucket_self_link" {
  description = "Self-link of the Terraform state bucket"
  value       = var.create_state_bucket && var.state_bucket_name != "" ? google_storage_bucket.terraform_state[0].self_link : null
}

output "otel_service_account_email" {
  description = "Email address of the OpenTelemetry collector service account"
  value       = var.create_workload_identities ? google_service_account.otel_collector[0].email : null
}

output "otel_service_account_id" {
  description = "The service account ID for OpenTelemetry collector"
  value       = var.create_workload_identities ? google_service_account.otel_collector[0].id : null
}

output "microservices_service_account_email" {
  description = "Email address of the microservices demo service account"
  value       = var.create_workload_identities ? google_service_account.microservices_demo[0].email : null
}

output "microservices_service_account_id" {
  description = "The service account ID for microservices demo"
  value       = var.create_workload_identities ? google_service_account.microservices_demo[0].id : null
}

output "enabled_apis" {
  description = "List of enabled GCP APIs"
  value       = [for api in google_project_service.required_apis : api.service]
}

output "state_prefix" {
  description = "Prefix for Terraform state files"
  value       = var.state_prefix
}

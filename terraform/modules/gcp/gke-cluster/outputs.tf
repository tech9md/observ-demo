# Outputs for GKE Cluster Module

output "cluster_id" {
  description = "The ID of the cluster"
  value       = google_container_cluster.autopilot.id
}

output "cluster_name" {
  description = "The name of the cluster"
  value       = google_container_cluster.autopilot.name
}

output "cluster_location" {
  description = "The location (region or zone) of the cluster"
  value       = google_container_cluster.autopilot.location
}

output "cluster_region" {
  description = "The region of the cluster"
  value       = var.region
}

output "cluster_zone" {
  description = "The zone of the cluster (for zonal clusters)"
  value       = var.regional_cluster ? null : var.zone
}

output "cluster_endpoint" {
  description = "The IP address of the cluster master"
  value       = google_container_cluster.autopilot.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The cluster CA certificate (base64 encoded)"
  value       = google_container_cluster.autopilot.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_master_version" {
  description = "The Kubernetes master version"
  value       = google_container_cluster.autopilot.master_version
}

output "cluster_self_link" {
  description = "The self-link of the cluster"
  value       = google_container_cluster.autopilot.self_link
}

output "workload_identity_pool" {
  description = "The Workload Identity pool"
  value       = "${var.project_id}.svc.id.goog"
}

output "network" {
  description = "The VPC network name"
  value       = var.network_name
}

output "subnetwork" {
  description = "The subnetwork name"
  value       = var.subnetwork_name
}

output "pods_range_name" {
  description = "The name of the secondary range for pods"
  value       = var.pods_range_name
}

output "services_range_name" {
  description = "The name of the secondary range for services"
  value       = var.services_range_name
}

output "master_ipv4_cidr_block" {
  description = "The IP range for the master network"
  value       = var.master_ipv4_cidr_block
}

output "otel_namespace" {
  description = "Kubernetes namespace for OpenTelemetry"
  value       = var.otel_namespace
}

output "otel_service_account_name" {
  description = "Kubernetes service account name for OpenTelemetry"
  value       = var.otel_service_account_name
}

output "microservices_namespace" {
  description = "Kubernetes namespace for microservices demo"
  value       = var.microservices_namespace
}

output "microservices_service_account_name" {
  description = "Kubernetes service account name for microservices demo"
  value       = var.microservices_service_account_name
}

output "dns_zone_name" {
  description = "Name of the Cloud DNS zone (if created)"
  value       = var.create_dns_zone ? google_dns_managed_zone.gke_zone[0].name : null
}

output "dns_zone_dns_name" {
  description = "DNS name of the Cloud DNS zone (if created)"
  value       = var.create_dns_zone ? google_dns_managed_zone.gke_zone[0].dns_name : null
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file (if generated)"
  value       = var.generate_kubeconfig ? var.kubeconfig_path : null
}

# Cluster configuration summary
output "cluster_summary" {
  description = "Summary of cluster configuration"
  value = {
    name               = google_container_cluster.autopilot.name
    location           = google_container_cluster.autopilot.location
    endpoint           = google_container_cluster.autopilot.endpoint
    autopilot_enabled  = google_container_cluster.autopilot.enable_autopilot
    private_nodes      = var.enable_private_nodes
    private_endpoint   = var.enable_private_endpoint
    workload_identity  = true
    release_channel    = var.release_channel
    master_version     = google_container_cluster.autopilot.master_version
    vpc_network        = var.network_name
    subnetwork         = var.subnetwork_name
    regional           = var.regional_cluster
    security_posture   = var.enable_security_posture
    managed_prometheus = var.enable_managed_prometheus
  }
}

# kubectl configuration command
output "kubectl_config_command" {
  description = "Command to configure kubectl for this cluster"
  value       = var.regional_cluster ? "gcloud container clusters get-credentials ${google_container_cluster.autopilot.name} --region ${var.region} --project ${var.project_id}" : "gcloud container clusters get-credentials ${google_container_cluster.autopilot.name} --zone ${var.zone} --project ${var.project_id}"
}

# Workload Identity annotation for Kubernetes service accounts
output "workload_identity_annotation" {
  description = "Annotation to add to Kubernetes service accounts for Workload Identity"
  value = {
    otel = {
      namespace            = var.otel_namespace
      service_account_name = var.otel_service_account_name
      annotation_key       = "iam.gke.io/gcp-service-account"
      annotation_value     = var.otel_service_account_email
    }
    microservices = {
      namespace            = var.microservices_namespace
      service_account_name = var.microservices_service_account_name
      annotation_key       = "iam.gke.io/gcp-service-account"
      annotation_value     = var.microservices_service_account_email
    }
  }
}

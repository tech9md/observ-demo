# GCP Observability Demo - Root Module Outputs
# Deployment information, URLs, and configuration details

# =============================================================================
# PROJECT INFORMATION
# =============================================================================

output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

# =============================================================================
# NETWORK OUTPUTS
# =============================================================================

output "network_name" {
  description = "VPC network name"
  value       = module.vpc_network.network_name
}

output "network_id" {
  description = "VPC network ID"
  value       = module.vpc_network.network_id
}

output "subnet_name" {
  description = "GKE subnet name"
  value       = module.vpc_network.gke_subnet_name
}

output "subnet_cidr" {
  description = "GKE nodes subnet CIDR"
  value       = module.vpc_network.gke_subnet_cidr
}

output "pods_cidr" {
  description = "GKE pods CIDR range"
  value       = module.vpc_network.gke_pods_cidr
}

output "services_cidr" {
  description = "GKE services CIDR range"
  value       = module.vpc_network.gke_services_cidr
}

output "static_ip" {
  description = "Static IP address for load balancer"
  value       = module.vpc_network.static_ip
}

output "nat_ip" {
  description = "Cloud NAT IP addresses"
  value       = module.vpc_network.nat_name
}

# =============================================================================
# GKE CLUSTER OUTPUTS
# =============================================================================

output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke_cluster.cluster_endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = module.gke_cluster.cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "GKE cluster location (region or zone)"
  value       = module.gke_cluster.cluster_location
}

output "cluster_type" {
  description = "GKE cluster type (regional or zonal)"
  value       = module.gke_cluster.cluster_type
}

output "cluster_version" {
  description = "GKE cluster Kubernetes version"
  value       = module.gke_cluster.cluster_version
}

output "workload_identity_pool" {
  description = "Workload Identity pool"
  value       = module.gke_cluster.workload_identity_pool
}

# =============================================================================
# SERVICE ACCOUNTS
# =============================================================================

output "terraform_service_account" {
  description = "Terraform service account email"
  value       = module.project_setup.terraform_service_account_email
}

output "otel_service_account" {
  description = "OpenTelemetry service account email"
  value       = module.project_setup.otel_service_account_email
}

output "microservices_service_account" {
  description = "Microservices demo service account email"
  value       = module.project_setup.microservices_service_account_email
}

# =============================================================================
# IAP (IDENTITY-AWARE PROXY) OUTPUTS
# =============================================================================

output "iap_enabled" {
  description = "Whether IAP is enabled"
  value       = var.enable_iap
}

output "iap_brand_name" {
  description = "IAP brand name"
  value       = var.enable_iap ? module.iap_config[0].brand_name : null
}

output "iap_oauth_client_id" {
  description = "IAP OAuth client ID"
  value       = var.enable_iap ? module.iap_config[0].oauth_client_id : null
  sensitive   = true
}

output "iap_static_ip" {
  description = "IAP load balancer static IP"
  value       = var.enable_iap ? module.iap_config[0].static_ip_address : null
}

output "iap_authorized_users" {
  description = "List of users authorized for IAP access"
  value       = var.enable_iap ? module.iap_config[0].iap_users : []
}

output "iap_ssl_domains" {
  description = "Domains covered by SSL certificate"
  value       = var.enable_iap && var.create_ssl_certificate ? module.iap_config[0].ssl_certificate_domains : []
}

# =============================================================================
# MONITORING OUTPUTS
# =============================================================================

output "monitoring_enabled" {
  description = "Whether monitoring is enabled"
  value       = true
}

output "notification_channels" {
  description = "Configured notification channels"
  value = {
    email     = var.notification_email != "" ? "configured" : "not configured"
    slack     = var.notification_slack != "" ? "configured" : "not configured"
    pagerduty = var.notification_pagerduty != "" ? "configured" : "not configured"
  }
}

output "alert_policies_count" {
  description = "Number of alert policies created"
  value       = module.monitoring.alert_policies_count
}

output "dashboards_created" {
  description = "List of created dashboards"
  value       = module.monitoring.dashboard_names
}

# =============================================================================
# BUDGET & COST OUTPUTS
# =============================================================================

output "budget_amount" {
  description = "Monthly budget amount"
  value       = "${var.currency_code} ${var.budget_amount}"
}

output "budget_name" {
  description = "Budget name"
  value       = module.budget_alerts.budget_name
}

output "budget_thresholds" {
  description = "Configured budget alert thresholds"
  value       = module.budget_alerts.threshold_rules
}

output "cost_pubsub_topic" {
  description = "Pub/Sub topic for budget alerts"
  value       = module.budget_alerts.pubsub_topic_name
}

# =============================================================================
# ACCESS INFORMATION
# =============================================================================

output "kubectl_command" {
  description = "Command to configure kubectl access"
  value       = var.regional_cluster ? "gcloud container clusters get-credentials ${module.gke_cluster.cluster_name} --region ${var.region} --project ${var.project_id}" : "gcloud container clusters get-credentials ${module.gke_cluster.cluster_name} --zone ${var.zone} --project ${var.project_id}"
}

output "access_urls" {
  description = "URLs for accessing services"
  value = {
    gke_console      = "https://console.cloud.google.com/kubernetes/clusters/details/${var.region}/${module.gke_cluster.cluster_name}?project=${var.project_id}"
    monitoring       = "https://console.cloud.google.com/monitoring?project=${var.project_id}"
    logging          = "https://console.cloud.google.com/logs?project=${var.project_id}"
    trace            = "https://console.cloud.google.com/traces?project=${var.project_id}"
    billing          = "https://console.cloud.google.com/billing?project=${var.project_id}"
    iap_applications = var.enable_iap ? "https://console.cloud.google.com/security/iap?project=${var.project_id}" : null
  }
}

# =============================================================================
# DEPLOYMENT SUMMARY
# =============================================================================

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    project_id         = var.project_id
    region             = var.region
    environment        = var.environment
    cluster_name       = module.gke_cluster.cluster_name
    cluster_type       = module.gke_cluster.cluster_type
    cluster_version    = module.gke_cluster.cluster_version
    network_name       = module.vpc_network.network_name
    iap_enabled        = var.enable_iap
    monitoring_enabled = true
    budget_amount      = "${var.currency_code} ${var.budget_amount}"
    static_ip          = module.vpc_network.static_ip
  }
}

# =============================================================================
# NEXT STEPS
# =============================================================================

output "next_steps" {
  description = "Next steps after Terraform deployment"
  value       = <<-EOT
    ========================================
    GCP Observability Demo - Deployment Complete
    ========================================

    1. Configure kubectl access:
       ${var.regional_cluster ? "gcloud container clusters get-credentials ${module.gke_cluster.cluster_name} --region ${var.region} --project ${var.project_id}" : "gcloud container clusters get-credentials ${module.gke_cluster.cluster_name} --zone ${var.zone} --project ${var.project_id}"}

    2. Verify cluster access:
       kubectl get nodes
       kubectl get namespaces

    3. Deploy OpenTelemetry demo:
       observ-demo deploy --otel

    4. Deploy Microservices demo:
       observ-demo deploy --microservices

    5. Generate traffic:
       observ-demo generate-traffic --pattern medium

    6. View monitoring dashboards:
       ${module.monitoring.dashboard_names != [] ? "Dashboards created: ${join(", ", module.monitoring.dashboard_names)}" : "Create dashboards via observ-demo CLI"}

    7. Access Cloud Console:
       GKE:        ${module.vpc_network.network_summary.network_name != "" ? "https://console.cloud.google.com/kubernetes/clusters/details/${var.region}/${module.gke_cluster.cluster_name}?project=${var.project_id}" : "Not available"}
       Monitoring: https://console.cloud.google.com/monitoring?project=${var.project_id}
       Trace:      https://console.cloud.google.com/traces?project=${var.project_id}

    ${var.enable_iap ? "\n8. Configure IAP access:\n   - Add authorized users: gcloud iap web add-iam-policy-binding --member=user:EMAIL --role=roles/iap.httpsResourceAccessor\n   - Access URL: https://${module.iap_config[0].static_ip_address != null ? module.iap_config[0].static_ip_address : "PENDING"}\n" : ""}
    ========================================
    Estimated Monthly Cost: $45-71 (24/7 operation)

    To reduce costs when not in use:
    - Scale to zero: kubectl scale deployment --all --replicas=0 -n opentelemetry
    - Full teardown: observ-demo teardown
    ========================================
  EOT
}

# =============================================================================
# CONSOLE LINKS
# =============================================================================

output "console_links" {
  description = "Quick links to GCP Console"
  value       = module.budget_alerts.budget_links
}

output "cost_optimization_tips" {
  description = "Cost optimization recommendations"
  value       = module.budget_alerts.cost_optimization_tips
}

# =============================================================================
# KUBERNETES CONFIGURATION
# =============================================================================

output "kubernetes_ingress_annotation" {
  description = "Kubernetes Ingress annotation for IAP"
  value       = var.enable_iap ? module.iap_config[0].kubernetes_ingress_annotation : {}
}

output "kubernetes_backend_config" {
  description = "Kubernetes BackendConfig YAML for IAP"
  value       = var.enable_iap ? module.iap_config[0].kubernetes_backend_config : ""
}

# =============================================================================
# TERRAFORM STATE
# =============================================================================

output "terraform_state_bucket" {
  description = "GCS bucket for Terraform state"
  value       = module.project_setup.state_bucket_name
}

output "terraform_state_location" {
  description = "Location of Terraform state"
  value       = "gs://${module.project_setup.state_bucket_name}/terraform/state"
}

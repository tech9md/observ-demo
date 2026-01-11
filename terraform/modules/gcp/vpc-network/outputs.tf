# Outputs for VPC Network Module

output "network_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "network_self_link" {
  description = "The self-link of the VPC network"
  value       = google_compute_network.vpc.self_link
}

output "gke_subnet_id" {
  description = "The ID of the GKE subnet"
  value       = google_compute_subnetwork.gke_subnet.id
}

output "gke_subnet_name" {
  description = "The name of the GKE subnet"
  value       = google_compute_subnetwork.gke_subnet.name
}

output "gke_subnet_self_link" {
  description = "The self-link of the GKE subnet"
  value       = google_compute_subnetwork.gke_subnet.self_link
}

output "gke_subnet_cidr" {
  description = "The CIDR range of the GKE nodes subnet"
  value       = google_compute_subnetwork.gke_subnet.ip_cidr_range
}

output "gke_pods_range_name" {
  description = "The name of the secondary IP range for GKE pods"
  value       = google_compute_subnetwork.gke_subnet.secondary_ip_range[0].range_name
}

output "gke_pods_cidr" {
  description = "The CIDR range for GKE pods"
  value       = google_compute_subnetwork.gke_subnet.secondary_ip_range[0].ip_cidr_range
}

output "gke_services_range_name" {
  description = "The name of the secondary IP range for GKE services"
  value       = google_compute_subnetwork.gke_subnet.secondary_ip_range[1].range_name
}

output "gke_services_cidr" {
  description = "The CIDR range for GKE services"
  value       = google_compute_subnetwork.gke_subnet.secondary_ip_range[1].ip_cidr_range
}

output "router_id" {
  description = "The ID of the Cloud Router"
  value       = google_compute_router.router.id
}

output "router_name" {
  description = "The name of the Cloud Router"
  value       = google_compute_router.router.name
}

output "nat_id" {
  description = "The ID of the Cloud NAT"
  value       = google_compute_router_nat.nat.id
}

output "nat_name" {
  description = "The name of the Cloud NAT"
  value       = google_compute_router_nat.nat.name
}

output "static_ip" {
  description = "The static IP address for load balancer (if created)"
  value       = var.create_static_ip ? google_compute_global_address.ingress_ip[0].address : null
}

output "static_ip_name" {
  description = "The name of the static IP address (if created)"
  value       = var.create_static_ip ? google_compute_global_address.ingress_ip[0].name : null
}

output "firewall_rules" {
  description = "List of created firewall rules"
  value = {
    allow_internal     = google_compute_firewall.allow_internal.name
    allow_health_checks = google_compute_firewall.allow_health_checks.name
    allow_iap          = google_compute_firewall.allow_iap.name
    deny_all_ingress   = google_compute_firewall.deny_all_ingress.name
    allow_egress       = google_compute_firewall.allow_egress.name
    allow_ssh          = var.enable_ssh_access ? google_compute_firewall.allow_ssh[0].name : null
  }
}

# Summary output for easy reference
output "network_summary" {
  description = "Summary of network configuration"
  value = {
    network_name         = google_compute_network.vpc.name
    region               = var.region
    gke_subnet          = google_compute_subnetwork.gke_subnet.name
    gke_nodes_cidr      = google_compute_subnetwork.gke_subnet.ip_cidr_range
    gke_pods_cidr       = google_compute_subnetwork.gke_subnet.secondary_ip_range[0].ip_cidr_range
    gke_services_cidr   = google_compute_subnetwork.gke_subnet.secondary_ip_range[1].ip_cidr_range
    cloud_nat_enabled   = true
    flow_logs_enabled   = var.enable_flow_logs
    static_ip_created   = var.create_static_ip
  }
}

# Outputs for IAP Configuration Module

output "brand_name" {
  description = "Name of the IAP brand"
  value       = var.create_brand ? google_iap_brand.project_brand[0].name : var.existing_brand_name
}

output "oauth_client_id" {
  description = "OAuth client ID"
  value       = var.create_oauth_client ? google_iap_client.iap_client[0].client_id : null
  sensitive   = true
}

output "oauth_client_secret" {
  description = "OAuth client secret"
  value       = var.create_oauth_client ? google_iap_client.iap_client[0].secret : null
  sensitive   = true
}

output "iap_users" {
  description = "List of users with IAP access"
  value       = var.iap_users
}

output "static_ip_address" {
  description = "Static IP address for load balancer"
  value       = var.create_static_ip ? google_compute_global_address.iap_lb_ip[0].address : null
}

output "static_ip_name" {
  description = "Name of the static IP address"
  value       = var.create_static_ip ? google_compute_global_address.iap_lb_ip[0].name : null
}

output "ssl_certificate_id" {
  description = "ID of the managed SSL certificate"
  value       = var.create_ssl_certificate && length(var.domains) > 0 ? google_compute_managed_ssl_certificate.iap_cert[0].id : null
}

output "ssl_certificate_name" {
  description = "Name of the managed SSL certificate"
  value       = var.create_ssl_certificate && length(var.domains) > 0 ? google_compute_managed_ssl_certificate.iap_cert[0].name : null
}

output "ssl_certificate_domains" {
  description = "Domains covered by the SSL certificate"
  value       = var.create_ssl_certificate && length(var.domains) > 0 ? google_compute_managed_ssl_certificate.iap_cert[0].managed[0].domains : []
}

output "url_map_id" {
  description = "ID of the URL map"
  value       = var.create_url_map ? google_compute_url_map.iap_url_map[0].id : var.url_map_id
}

output "https_proxy_id" {
  description = "ID of the HTTPS proxy"
  value       = var.create_https_proxy ? google_compute_target_https_proxy.iap_https_proxy[0].id : null
}

output "forwarding_rule_ip" {
  description = "IP address of the forwarding rule"
  value       = var.create_forwarding_rule ? google_compute_global_forwarding_rule.iap_https[0].ip_address : null
}

output "security_policy_id" {
  description = "ID of the Cloud Armor security policy"
  value       = var.create_security_policy ? google_compute_security_policy.iap_policy[0].id : null
}

output "security_policy_name" {
  description = "Name of the Cloud Armor security policy"
  value       = var.create_security_policy ? google_compute_security_policy.iap_policy[0].name : null
}

output "firewall_rule_name" {
  description = "Name of the IAP firewall rule"
  value       = var.create_firewall_rule ? google_compute_firewall.allow_iap[0].name : null
}

output "tunnel_service_account_email" {
  description = "Email of the IAP tunnel service account"
  value       = var.create_tunnel_service_account ? google_service_account.iap_tunnel[0].email : null
}

# Configuration summary
output "iap_summary" {
  description = "Summary of IAP configuration"
  value = {
    brand_created           = var.create_brand
    oauth_client_created    = var.create_oauth_client
    authorized_users_count  = length(var.iap_users)
    backend_services_count  = length(var.backend_service_names)
    static_ip_created       = var.create_static_ip
    ssl_certificate_created = var.create_ssl_certificate && length(var.domains) > 0
    security_policy_created = var.create_security_policy
    rate_limiting_enabled   = var.enable_rate_limiting
    firewall_rule_created   = var.create_firewall_rule
  }
}

# Access instructions
output "access_instructions" {
  description = "Instructions for accessing IAP-protected resources"
  value = var.create_static_ip ? join("\n", [
    "IAP-Protected Resources Access:",
    "",
    "1. Ensure you're authenticated with Google Cloud:",
    "   gcloud auth login",
    "",
    "2. Access the application:",
    "   URL: https://${google_compute_global_address.iap_lb_ip[0].address}",
    "",
    "3. You'll be prompted to sign in with Google",
    "   Authorized users: ${join(", ", var.iap_users)}",
    "",
    "4. For SSH/RDP via IAP tunnel (if enabled):",
    "   gcloud compute ssh INSTANCE_NAME --tunnel-through-iap",
    "   gcloud compute start-iap-tunnel INSTANCE_NAME PORT --local-host-port=localhost:LOCAL_PORT",
    "",
    "5. Troubleshooting:",
    "   - Verify you're in the authorized users list",
    "   - Check IAM permissions: roles/iap.httpsResourceAccessor",
    "   - Review logs: gcloud logging read 'resource.type=gce_backend_service'"
  ]) : "IAP configuration pending - static IP not created"
}

# Kubernetes annotation for IAP
output "kubernetes_ingress_annotation" {
  description = "Annotation to add to Kubernetes Ingress for IAP"
  value = var.create_oauth_client ? {
    "ingress.gcp.kubernetes.io/pre-shared-cert"   = var.create_ssl_certificate && length(var.domains) > 0 ? google_compute_managed_ssl_certificate.iap_cert[0].name : "your-cert-name"
    "cloud.google.com/backend-config"             = "iap-backend-config"
    "kubernetes.io/ingress.global-static-ip-name" = var.create_static_ip ? google_compute_global_address.iap_lb_ip[0].name : "your-ip-name"
    "cloud.google.com/armor-config"               = var.create_security_policy ? google_compute_security_policy.iap_policy[0].name : null
  } : {}
}

# Backend config for Kubernetes
output "kubernetes_backend_config" {
  description = "BackendConfig YAML for Kubernetes"
  value = var.create_oauth_client ? yamlencode({
    apiVersion = "cloud.google.com/v1"
    kind       = "BackendConfig"
    metadata = {
      name = "iap-backend-config"
    }
    spec = {
      iap = {
        enabled = true
        oauthclientCredentials = {
          secretName = "iap-oauth-credentials"
        }
      }
      securityPolicy = var.create_security_policy ? {
        name = google_compute_security_policy.iap_policy[0].name
      } : null
    }
  }) : ""
}

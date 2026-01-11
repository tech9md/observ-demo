# Outputs for Cloud Monitoring Module

output "notification_channel_ids" {
  description = "IDs of all notification channels"
  value       = local.all_notification_channels
}

output "email_notification_channels" {
  description = "Map of email notification channels"
  value = {
    for email, channel in google_monitoring_notification_channel.email :
    email => {
      id   = channel.id
      name = channel.name
    }
  }
}

output "slack_notification_channel_id" {
  description = "ID of Slack notification channel"
  value       = var.slack_webhook_url != "" ? google_monitoring_notification_channel.slack[0].id : null
}

output "pagerduty_notification_channel_id" {
  description = "ID of PagerDuty notification channel"
  value       = var.pagerduty_service_key != "" ? google_monitoring_notification_channel.pagerduty[0].id : null
}

output "alert_policy_ids" {
  description = "Map of alert policy names to IDs"
  value = {
    gke_cluster_health  = var.enable_gke_alerts ? google_monitoring_alert_policy.gke_cluster_health.id : null
    pod_crash_loop      = var.enable_pod_alerts ? google_monitoring_alert_policy.pod_crash_loop.id : null
    high_error_rate     = var.enable_error_alerts ? google_monitoring_alert_policy.high_error_rate.id : null
    high_cpu            = var.enable_resource_alerts ? google_monitoring_alert_policy.high_cpu.id : null
    high_memory         = var.enable_resource_alerts ? google_monitoring_alert_policy.high_memory.id : null
    deployment_failure  = var.enable_deployment_alerts ? google_monitoring_alert_policy.deployment_failure.id : null
    lb_errors           = var.enable_lb_alerts ? google_monitoring_alert_policy.lb_errors.id : null
    uptime_alert        = var.create_uptime_checks ? google_monitoring_alert_policy.uptime_alert[0].id : null
  }
}

output "dashboard_ids" {
  description = "IDs of created dashboards"
  value = {
    overview    = google_monitoring_dashboard.overview.id
    gke_metrics = var.create_gke_dashboard ? google_monitoring_dashboard.gke_metrics[0].id : null
  }
}

output "dashboard_urls" {
  description = "URLs to view dashboards in Cloud Console"
  value = {
    overview = "https://console.cloud.google.com/monitoring/dashboards/custom/${split("/", google_monitoring_dashboard.overview.id)[1]}?project=${var.project_id}"
    gke_metrics = var.create_gke_dashboard ? "https://console.cloud.google.com/monitoring/dashboards/custom/${split("/", google_monitoring_dashboard.gke_metrics[0].id)[1]}?project=${var.project_id}" : null
  }
}

output "uptime_check_id" {
  description = "ID of the uptime check"
  value       = var.create_uptime_checks ? google_monitoring_uptime_check_config.app_uptime[0].uptime_check_id : null
}

output "monitoring_summary" {
  description = "Summary of monitoring configuration"
  value = {
    notification_channels = {
      email_count      = length(var.notification_emails)
      slack_configured = var.slack_webhook_url != ""
      pagerduty_configured = var.pagerduty_service_key != ""
    }
    alert_policies = {
      gke_alerts        = var.enable_gke_alerts
      pod_alerts        = var.enable_pod_alerts
      error_alerts      = var.enable_error_alerts
      resource_alerts   = var.enable_resource_alerts
      deployment_alerts = var.enable_deployment_alerts
      lb_alerts         = var.enable_lb_alerts
    }
    dashboards = {
      overview_created    = true
      gke_metrics_created = var.create_gke_dashboard
    }
    uptime_checks = {
      enabled = var.create_uptime_checks
      host    = var.uptime_check_host
    }
  }
}

output "alert_thresholds" {
  description = "Configured alert thresholds"
  value = {
    error_rate_per_sec = var.error_rate_threshold
    cpu_cores          = var.cpu_threshold
    memory_bytes       = var.memory_threshold_bytes
    lb_errors_per_sec  = var.lb_error_threshold
  }
}

# Quick links for common monitoring tasks
output "monitoring_links" {
  description = "Useful monitoring console links"
  value = {
    metrics_explorer  = "https://console.cloud.google.com/monitoring/metrics-explorer?project=${var.project_id}"
    alert_policies    = "https://console.cloud.google.com/monitoring/alerting/policies?project=${var.project_id}"
    uptime_checks     = "https://console.cloud.google.com/monitoring/uptime?project=${var.project_id}"
    dashboards        = "https://console.cloud.google.com/monitoring/dashboards?project=${var.project_id}"
    logs_explorer     = "https://console.cloud.google.com/logs/query?project=${var.project_id}"
    trace_list        = "https://console.cloud.google.com/traces/list?project=${var.project_id}"
  }
}

# Cloud Monitoring Module
# This module configures comprehensive monitoring, alerting, and dashboards
# for the observability demo infrastructure.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Email notification channel
resource "google_monitoring_notification_channel" "email" {
  for_each = toset(var.notification_emails)

  project      = var.project_id
  display_name = "Email: ${each.value}"
  type         = "email"

  labels = {
    email_address = each.value
  }

  enabled = true
}

# Slack notification channel
resource "google_monitoring_notification_channel" "slack" {
  count = var.slack_webhook_url != "" ? 1 : 0

  project      = var.project_id
  display_name = "Slack Webhook"
  type         = "slack"

  labels = {
    channel_name = var.slack_channel_name
  }

  sensitive_labels {
    auth_token = var.slack_webhook_url
  }

  enabled = true
}

# PagerDuty notification channel (optional)
resource "google_monitoring_notification_channel" "pagerduty" {
  count = var.pagerduty_service_key != "" ? 1 : 0

  project      = var.project_id
  display_name = "PagerDuty"
  type         = "pagerduty"

  sensitive_labels {
    service_key = var.pagerduty_service_key
  }

  enabled = true
}

# Combine all notification channels
locals {
  all_notification_channels = concat(
    [for ch in google_monitoring_notification_channel.email : ch.id],
    google_monitoring_notification_channel.slack[*].id,
    google_monitoring_notification_channel.pagerduty[*].id
  )
}

# Alert Policy: GKE Cluster Health (based on node allocatable resources)
resource "google_monitoring_alert_policy" "gke_cluster_health" {
  project      = var.project_id
  display_name = "GKE Cluster Health Check"
  combiner     = "OR"
  enabled      = var.enable_gke_alerts

  conditions {
    display_name = "GKE Node Allocatable CPU"

    condition_threshold {
      # Use node allocatable cores as a proxy for cluster health
      filter          = "resource.type = \"k8s_node\" AND metric.type = \"kubernetes.io/node/cpu/allocatable_cores\""
      comparison      = "COMPARISON_LT"
      threshold_value = 0.1 # Alert if allocatable cores drops to near zero
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = local.all_notification_channels

  alert_strategy {
    auto_close = "1800s" # Auto-close after 30 minutes
  }

  documentation {
    content   = "GKE cluster health check failed. Node allocatable resources are low. Check cluster status in GCP Console."
    mime_type = "text/markdown"
  }
}

# Alert Policy: Pod Crash Loops
resource "google_monitoring_alert_policy" "pod_crash_loop" {
  project      = var.project_id
  display_name = "Pod Crash Loop Detected"
  combiner     = "OR"
  enabled      = var.enable_pod_alerts

  conditions {
    display_name = "High Pod Restart Count"

    condition_threshold {
      filter          = "resource.type = \"k8s_pod\" AND metric.type = \"kubernetes.io/pod/restart_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = 3
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.namespace_name", "resource.pod_name"]
      }
    }
  }

  notification_channels = local.all_notification_channels

  alert_strategy {
    auto_close = "3600s"
  }

  documentation {
    content   = <<-EOT
      Pod crash loop detected.

      **Action Items:**
      1. Check pod logs: `kubectl logs <pod-name> -n <namespace>`
      2. Describe pod: `kubectl describe pod <pod-name> -n <namespace>`
      3. Check events: `kubectl get events -n <namespace>`
    EOT
    mime_type = "text/markdown"
  }
}

# Alert Policy: High Error Rate
resource "google_monitoring_alert_policy" "high_error_rate" {
  project      = var.project_id
  display_name = "High Application Error Rate"
  combiner     = "OR"
  enabled      = var.enable_error_alerts

  conditions {
    display_name = "Error Log Rate"

    condition_threshold {
      filter          = "resource.type = \"k8s_container\" AND metric.type = \"logging.googleapis.com/log_entry_count\" AND metric.labels.severity = \"ERROR\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.error_rate_threshold
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = local.all_notification_channels

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "High error rate detected in application logs. Investigate recent deployments and check error patterns."
    mime_type = "text/markdown"
  }
}

# Alert Policy: High CPU Usage
resource "google_monitoring_alert_policy" "high_cpu" {
  project      = var.project_id
  display_name = "High CPU Usage"
  combiner     = "OR"
  enabled      = var.enable_resource_alerts

  conditions {
    display_name = "Container CPU Usage"

    condition_threshold {
      filter          = "resource.type = \"k8s_container\" AND metric.type = \"kubernetes.io/container/cpu/core_usage_time\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cpu_threshold
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = local.all_notification_channels

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "High CPU usage detected. Consider scaling or optimizing workloads."
    mime_type = "text/markdown"
  }
}

# Alert Policy: High Memory Usage
resource "google_monitoring_alert_policy" "high_memory" {
  project      = var.project_id
  display_name = "High Memory Usage"
  combiner     = "OR"
  enabled      = var.enable_resource_alerts

  conditions {
    display_name = "Container Memory Usage"

    condition_threshold {
      filter          = "resource.type = \"k8s_container\" AND metric.type = \"kubernetes.io/container/memory/used_bytes\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.memory_threshold_bytes
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.all_notification_channels

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "High memory usage detected. Check for memory leaks or scale workloads."
    mime_type = "text/markdown"
  }
}

# Alert Policy: Deployment Failures (using container restart count as proxy)
resource "google_monitoring_alert_policy" "deployment_failure" {
  project      = var.project_id
  display_name = "Deployment Failure Detected"
  combiner     = "OR"
  enabled      = var.enable_deployment_alerts

  conditions {
    display_name = "Container Restart Rate"

    condition_threshold {
      # Use container restart count as a proxy for deployment issues
      filter          = "resource.type = \"k8s_container\" AND metric.type = \"kubernetes.io/container/restart_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5 # More than 5 restarts in the period indicates issues
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.namespace_name", "resource.labels.pod_name"]
      }
    }
  }

  notification_channels = local.all_notification_channels

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "High container restart rate detected, indicating potential deployment issues. Check deployment status and pod events."
    mime_type = "text/markdown"
  }
}

# Alert Policy: Load Balancer Errors
resource "google_monitoring_alert_policy" "lb_errors" {
  project      = var.project_id
  display_name = "Load Balancer Error Rate"
  combiner     = "OR"
  enabled      = var.enable_lb_alerts

  conditions {
    display_name = "LB 5xx Errors"

    condition_threshold {
      filter          = "resource.type = \"https_lb_rule\" AND metric.type = \"loadbalancing.googleapis.com/https/request_count\" AND metric.label.response_code_class = \"500\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.lb_error_threshold
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = local.all_notification_channels

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "Load balancer returning 5xx errors. Check backend service health and capacity."
    mime_type = "text/markdown"
  }
}

# Dashboard: Observability Demo Overview
resource "google_monitoring_dashboard" "overview" {
  project = var.project_id
  dashboard_json = templatefile("${path.module}/dashboards/overview.json.tpl", {
    project_id   = var.project_id
    cluster_name = var.cluster_name
  })
}

# Dashboard: GKE Cluster Metrics
resource "google_monitoring_dashboard" "gke_metrics" {
  count = var.create_gke_dashboard ? 1 : 0

  project = var.project_id
  dashboard_json = templatefile("${path.module}/dashboards/gke-metrics.json.tpl", {
    project_id   = var.project_id
    cluster_name = var.cluster_name
  })
}

# Uptime check for application (optional)
resource "google_monitoring_uptime_check_config" "app_uptime" {
  count = var.create_uptime_checks ? 1 : 0

  project      = var.project_id
  display_name = "Application Uptime Check"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = var.uptime_check_path
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.uptime_check_host
    }
  }

  content_matchers {
    content = var.uptime_check_content
    matcher = "CONTAINS_STRING"
  }
}

# Alert Policy for Uptime Check
resource "google_monitoring_alert_policy" "uptime_alert" {
  count = var.create_uptime_checks ? 1 : 0

  project      = var.project_id
  display_name = "Application Downtime Alert"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Uptime Check Failed"

    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" resource.type=\"uptime_url\" metric.label.check_id=\"${google_monitoring_uptime_check_config.app_uptime[0].uptime_check_id}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "300s"

      aggregations {
        alignment_period     = "1200s"
        per_series_aligner   = "ALIGN_FRACTION_TRUE"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.*"]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = local.all_notification_channels

  documentation {
    content   = "Application uptime check failed. Service may be down or experiencing issues."
    mime_type = "text/markdown"
  }
}

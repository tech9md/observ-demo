# Budget Alerts Module
# This module configures Cloud Billing budgets and cost alerts
# to monitor and control cloud spending.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Pub/Sub topic for budget notifications
resource "google_pubsub_topic" "budget_alerts" {
  project = var.project_id
  name    = "${var.budget_name}-alerts"

  labels = var.labels
}

# Pub/Sub subscription for programmatic access
resource "google_pubsub_subscription" "budget_alerts_subscription" {
  count = var.create_pubsub_subscription ? 1 : 0

  project = var.project_id
  name    = "${var.budget_name}-alerts-subscription"
  topic   = google_pubsub_topic.budget_alerts.name

  # Message retention
  message_retention_duration = "604800s" # 7 days

  # Acknowledgment deadline
  ack_deadline_seconds = 20

  # Expiration policy
  expiration_policy {
    ttl = "" # Never expire
  }

  labels = var.labels
}

# Cloud Billing Budget
resource "google_billing_budget" "budget" {
  billing_account = var.billing_account
  display_name    = var.budget_name

  budget_filter {
    projects = ["projects/${var.project_id}"]

    # Filter by services (optional)
    dynamic "services" {
      for_each = length(var.services) > 0 ? [1] : []
      content {
        service_ids = var.services
      }
    }

    # Filter by labels (optional)
    dynamic "labels" {
      for_each = length(var.budget_labels) > 0 ? [1] : []
      content {
        values = var.budget_labels
      }
    }

    # Calendar period or custom period
    calendar_period = var.calendar_period

    # Credit types to include
    credit_types_treatment = var.credit_treatment
  }

  # Budget amount
  amount {
    specified_amount {
      currency_code = var.currency_code
      units         = tostring(floor(var.budget_amount))
      nanos         = floor((var.budget_amount - floor(var.budget_amount)) * 1000000000)
    }
  }

  # Threshold rules for alerts
  dynamic "threshold_rules" {
    for_each = var.threshold_rules
    content {
      threshold_percent = threshold_rules.value.threshold_percent
      spend_basis       = threshold_rules.value.spend_basis
    }
  }

  # Notification channels
  all_updates_rule {
    pubsub_topic = google_pubsub_topic.budget_alerts.id

    # Monitoring notification channels (from monitoring module)
    monitoring_notification_channels = var.monitoring_notification_channels

    # Disable default IAM recipients
    disable_default_iam_recipients = var.disable_default_iam_recipients

    # Schema version
    schema_version = "1.0"
  }
}

# Cloud Function for budget alert handling (optional)
resource "google_storage_bucket" "function_bucket" {
  count = var.create_alert_function ? 1 : 0

  project  = var.project_id
  name     = "${var.project_id}-budget-function"
  location = var.region

  uniform_bucket_level_access = true
  force_destroy               = true

  labels = var.labels
}

# Service account for Cloud Function
resource "google_service_account" "budget_function" {
  count = var.create_alert_function ? 1 : 0

  project      = var.project_id
  account_id   = "budget-alert-function"
  display_name = "Budget Alert Function Service Account"
  description  = "Service account for budget alert Cloud Function"
}

# Grant necessary permissions to function service account
resource "google_project_iam_member" "function_invoker" {
  count = var.create_alert_function ? 1 : 0

  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.budget_function[0].email}"
}

# Pub/Sub IAM binding for Cloud Function
resource "google_pubsub_topic_iam_member" "function_subscriber" {
  count = var.create_alert_function ? 1 : 0

  project = var.project_id
  topic   = google_pubsub_topic.budget_alerts.name
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.budget_function[0].email}"
}

# Monitoring alert for budget exceeded
resource "google_monitoring_alert_policy" "budget_exceeded" {
  count = var.create_monitoring_alert ? 1 : 0

  project      = var.project_id
  display_name = "Budget Exceeded Alert"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Budget Threshold Exceeded"

    condition_threshold {
      filter          = "metric.type=\"billing.googleapis.com/project/costs\" resource.type=\"billing_account\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.budget_amount
      duration        = "0s"

      aggregations {
        alignment_period     = "3600s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = var.monitoring_notification_channels

  documentation {
    content = <<-EOT
      Monthly budget threshold exceeded!

      **Current Budget:** ${var.currency_code} ${var.budget_amount}

      **Action Items:**
      1. Review Cloud Billing reports: https://console.cloud.google.com/billing
      2. Check resource usage by service
      3. Consider scaling down or pausing non-essential resources
      4. Review and optimize:
         - GKE cluster size
         - Load balancer usage
         - Log retention policies
         - Trace sampling rates

      **Cost Optimization:**
      - Scale GKE deployments to zero during off-hours
      - Enable log exclusion filters
      - Reduce trace sampling rate
      - Use committed use discounts
    EOT
    mime_type = "text/markdown"
  }
}

# Custom metric for cost tracking (optional)
resource "google_logging_metric" "cost_metric" {
  count = var.create_cost_metric ? 1 : 0

  project = var.project_id
  name    = "billing_cost_total"
  filter  = "protoPayload.serviceName=\"billing.googleapis.com\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "DOUBLE"
    unit        = var.currency_code

    labels {
      key         = "service"
      value_type  = "STRING"
      description = "GCP service name"
    }
  }

  value_extractor = "EXTRACT(protoPayload.metadata.cost)"

  label_extractors = {
    "service" = "EXTRACT(protoPayload.metadata.serviceName)"
  }
}

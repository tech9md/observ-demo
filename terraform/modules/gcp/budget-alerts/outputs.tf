# Outputs for Budget Alerts Module

output "budget_name" {
  description = "Name of the budget"
  value       = google_billing_budget.budget.display_name
}

output "budget_id" {
  description = "ID of the budget"
  value       = google_billing_budget.budget.name
}

output "budget_amount" {
  description = "Monthly budget amount"
  value       = var.budget_amount
}

output "currency_code" {
  description = "Currency code for the budget"
  value       = var.currency_code
}

output "pubsub_topic_id" {
  description = "ID of the Pub/Sub topic for budget alerts"
  value       = google_pubsub_topic.budget_alerts.id
}

output "pubsub_topic_name" {
  description = "Name of the Pub/Sub topic for budget alerts"
  value       = google_pubsub_topic.budget_alerts.name
}

output "pubsub_subscription_id" {
  description = "ID of the Pub/Sub subscription"
  value       = var.create_pubsub_subscription ? google_pubsub_subscription.budget_alerts_subscription[0].id : null
}

output "pubsub_subscription_name" {
  description = "Name of the Pub/Sub subscription"
  value       = var.create_pubsub_subscription ? google_pubsub_subscription.budget_alerts_subscription[0].name : null
}

output "function_service_account_email" {
  description = "Email of the Cloud Function service account"
  value       = var.create_alert_function ? google_service_account.budget_function[0].email : null
}

output "monitoring_alert_id" {
  description = "ID of the budget monitoring alert policy"
  value       = var.create_monitoring_alert ? google_monitoring_alert_policy.budget_exceeded[0].id : null
}

output "cost_metric_name" {
  description = "Name of the cost tracking metric"
  value       = var.create_cost_metric ? google_logging_metric.cost_metric[0].name : null
}

output "threshold_rules" {
  description = "Configured threshold rules"
  value = [
    for rule in var.threshold_rules : {
      threshold = "${rule.threshold_percent * 100}%"
      basis     = rule.spend_basis
    }
  ]
}

output "budget_summary" {
  description = "Summary of budget configuration"
  value = {
    name           = google_billing_budget.budget.display_name
    amount         = "${var.currency_code} ${var.budget_amount}"
    period         = var.calendar_period
    threshold_count = length(var.threshold_rules)
    pubsub_topic   = google_pubsub_topic.budget_alerts.name
    alerts_enabled = var.create_monitoring_alert
  }
}

# Console links
output "budget_links" {
  description = "Useful budget console links"
  value = {
    billing_overview = "https://console.cloud.google.com/billing?project=${var.project_id}"
    budgets          = "https://console.cloud.google.com/billing/budgets?project=${var.project_id}"
    cost_table       = "https://console.cloud.google.com/billing/${var.billing_account}/reports?project=${var.project_id}"
    cost_breakdown   = "https://console.cloud.google.com/billing/${var.billing_account}/reports?project=${var.project_id}&breakdown=SERVICE"
  }
}

# Cost optimization recommendations
output "cost_optimization_tips" {
  description = "Cost optimization recommendations"
  value = <<-EOT
    Cost Optimization Tips:

    1. **GKE Autopilot**: Already using pay-per-pod pricing
    2. **Resource Quotas**: Set in GKE to prevent runaway costs
    3. **Log Filtering**: Exclude debug/info logs in production
    4. **Trace Sampling**: Sample at 10% instead of 100%
    5. **Auto-Shutdown**: Scale deployments to zero during off-hours
    6. **Committed Use**: Consider committed use discounts for predictable workloads
    7. **Preemptible VMs**: Use for non-critical workloads (up to 80% savings)
    8. **Regional Resources**: Use regional instead of multi-regional where possible

    **Estimated Costs (24/7):**
    - GKE Autopilot (2 vCPU, 4GB): ~$25-30/month
    - Cloud Load Balancing: ~$18-22/month
    - Cloud Trace: ~$5-10/month
    - Cloud Monitoring: ~$5-8/month
    - Cloud Logging: ~$2-5/month
    - **Total**: ~$45-71/month

    **To reduce costs:**
    - Scale to zero when not demoing: `kubectl scale deployment --all --replicas=0`
    - Use shutdown script: `./scripts/shutdown.sh`
  EOT
}

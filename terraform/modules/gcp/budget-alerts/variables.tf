# Variables for Budget Alerts Module

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "billing_account" {
  description = "The GCP billing account ID"
  type        = string

  validation {
    condition     = can(regex("^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$", var.billing_account))
    error_message = "Billing account must be in format: XXXXXX-XXXXXX-XXXXXX (uppercase letters and numbers)."
  }
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

# Budget configuration
variable "budget_name" {
  description = "Name of the budget"
  type        = string
  default     = "observ-demo-budget"
}

variable "budget_amount" {
  description = "Monthly budget amount in the specified currency"
  type        = number

  validation {
    condition     = var.budget_amount > 0
    error_message = "Budget amount must be greater than 0."
  }
}

variable "currency_code" {
  description = "Currency code (e.g., USD, EUR, GBP)"
  type        = string
  default     = "USD"

  validation {
    condition     = length(var.currency_code) == 3 && upper(var.currency_code) == var.currency_code
    error_message = "Currency code must be a 3-letter uppercase code (e.g., USD)."
  }
}

variable "calendar_period" {
  description = "Calendar period for budget (MONTH, QUARTER, YEAR)"
  type        = string
  default     = "MONTH"

  validation {
    condition     = contains(["MONTH", "QUARTER", "YEAR"], var.calendar_period)
    error_message = "Calendar period must be MONTH, QUARTER, or YEAR."
  }
}

# Threshold rules
variable "threshold_rules" {
  description = "List of threshold rules for budget alerts"
  type = list(object({
    threshold_percent = number
    spend_basis       = string # CURRENT_SPEND or FORECASTED_SPEND
  }))
  default = [
    {
      threshold_percent = 0.5 # 50%
      spend_basis       = "CURRENT_SPEND"
    },
    {
      threshold_percent = 0.75 # 75%
      spend_basis       = "CURRENT_SPEND"
    },
    {
      threshold_percent = 0.9 # 90%
      spend_basis       = "CURRENT_SPEND"
    },
    {
      threshold_percent = 1.0 # 100%
      spend_basis       = "CURRENT_SPEND"
    },
    {
      threshold_percent = 1.0 # 100% forecasted
      spend_basis       = "FORECASTED_SPEND"
    }
  ]

  validation {
    condition = alltrue([
      for rule in var.threshold_rules :
      rule.threshold_percent > 0 && rule.threshold_percent <= 2.0
    ])
    error_message = "Threshold percent must be between 0 and 2.0 (200%)."
  }

  validation {
    condition = alltrue([
      for rule in var.threshold_rules :
      contains(["CURRENT_SPEND", "FORECASTED_SPEND"], rule.spend_basis)
    ])
    error_message = "Spend basis must be CURRENT_SPEND or FORECASTED_SPEND."
  }
}

# Filters
variable "services" {
  description = "List of service IDs to include in budget (empty = all services)"
  type        = list(string)
  default     = []
}

variable "budget_labels" {
  description = "Labels to filter budget by"
  type        = map(string)
  default     = {}
}

variable "credit_treatment" {
  description = "How to treat credits (INCLUDE_ALL_CREDITS, EXCLUDE_ALL_CREDITS, INCLUDE_SPECIFIED_CREDITS)"
  type        = string
  default     = "INCLUDE_ALL_CREDITS"

  validation {
    condition     = contains(["INCLUDE_ALL_CREDITS", "EXCLUDE_ALL_CREDITS", "INCLUDE_SPECIFIED_CREDITS"], var.credit_treatment)
    error_message = "Credit treatment must be INCLUDE_ALL_CREDITS, EXCLUDE_ALL_CREDITS, or INCLUDE_SPECIFIED_CREDITS."
  }
}

# Notifications
variable "monitoring_notification_channels" {
  description = "List of monitoring notification channel IDs"
  type        = list(string)
  default     = []
}

variable "disable_default_iam_recipients" {
  description = "Disable sending budget alerts to default IAM recipients"
  type        = bool
  default     = false
}

# Pub/Sub
variable "create_pubsub_subscription" {
  description = "Create Pub/Sub subscription for programmatic access"
  type        = bool
  default     = false # Disabled by default - enable for programmatic budget alert handling
}

# Cloud Function
variable "create_alert_function" {
  description = "Create Cloud Function for budget alert handling"
  type        = bool
  default     = false # Set to true if custom alert logic needed
}

# Monitoring integration
variable "create_monitoring_alert" {
  description = "Create Cloud Monitoring alert for budget exceeded. Requires billing metrics to be available."
  type        = bool
  default     = false # Disabled by default - billing metrics may not be immediately available
}

variable "create_cost_metric" {
  description = "Create custom logging metric for cost tracking"
  type        = bool
  default     = false
}

# Labels
variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default = {
    managed-by = "terraform"
    component  = "budget-alerts"
  }
}

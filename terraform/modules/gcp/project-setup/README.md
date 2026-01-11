# GCP Project Setup Module

This Terraform module configures the foundational infrastructure for the observability demo automation platform on Google Cloud Platform.

## Features

- ✅ Enables all required GCP APIs automatically
- ✅ Creates Terraform service account with least-privilege permissions
- ✅ Sets up GCS bucket for Terraform state with versioning
- ✅ Creates service accounts for Workload Identity (OpenTelemetry, Microservices)
- ✅ Configures IAM permissions for all service accounts
- ✅ Implements security best practices

## Usage

```hcl
module "project_setup" {
  source = "./modules/gcp/project-setup"

  project_id        = "my-observ-demo"
  region            = "us-central1"
  state_bucket_name = "my-observ-demo-terraform-state"
  environment       = "dev"
  billing_account   = "012345-6789AB-CDEF01"

  labels = {
    managed-by = "terraform"
    project    = "observability-demo"
    team       = "platform"
  }
}
```

## Enabled APIs

This module automatically enables the following GCP APIs:

| API | Purpose |
|-----|---------|
| compute.googleapis.com | Compute Engine (VMs, networking) |
| container.googleapis.com | Google Kubernetes Engine |
| cloudresourcemanager.googleapis.com | Project and resource management |
| iam.googleapis.com | Identity and Access Management |
| logging.googleapis.com | Cloud Logging |
| monitoring.googleapis.com | Cloud Monitoring |
| cloudtrace.googleapis.com | Cloud Trace for distributed tracing |
| servicenetworking.googleapis.com | VPC service networking |
| storage.googleapis.com | Cloud Storage |
| secretmanager.googleapis.com | Secret Manager |
| cloudbilling.googleapis.com | Cloud Billing |
| iap.googleapis.com | Identity-Aware Proxy |

## Service Accounts Created

### 1. Terraform Automation SA
- **Account ID**: `terraform-automation`
- **Purpose**: Execute Terraform operations
- **Roles**:
  - `roles/compute.networkAdmin` - VPC management
  - `roles/container.admin` - GKE management
  - `roles/iam.serviceAccountAdmin` - Service account creation
  - `roles/iam.serviceAccountUser` - Service account impersonation
  - `roles/resourcemanager.projectIamAdmin` - IAM management
  - `roles/storage.admin` - GCS management
  - `roles/monitoring.admin` - Cloud Monitoring
  - `roles/logging.admin` - Cloud Logging

### 2. OpenTelemetry Collector SA (Optional)
- **Account ID**: `otel-collector`
- **Purpose**: OpenTelemetry collector with observability permissions
- **Roles**:
  - `roles/cloudtrace.agent` - Write traces to Cloud Trace
  - `roles/monitoring.metricWriter` - Write metrics to Cloud Monitoring
  - `roles/logging.logWriter` - Write logs to Cloud Logging

### 3. Microservices Demo SA (Optional)
- **Account ID**: `microservices-demo`
- **Purpose**: Google Microservices Demo application
- **Roles**:
  - `roles/cloudtrace.agent`
  - `roles/monitoring.metricWriter`
  - `roles/logging.logWriter`

## Terraform State Bucket

The module creates a GCS bucket for Terraform state with:

- **Versioning**: Enabled (keeps last 5 versions)
- **Encryption**: Google-managed encryption
- **Access Control**: Uniform bucket-level access
- **Lifecycle**: Automatic deletion of old versions
- **Force Destroy**: Enabled only in non-prod environments

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The GCP project ID | `string` | n/a | yes |
| region | The primary GCP region | `string` | `"us-central1"` | no |
| state_bucket_name | Name of the GCS bucket for Terraform state | `string` | n/a | yes |
| state_prefix | Prefix for Terraform state files | `string` | `"terraform/state"` | no |
| enable_versioning | Enable versioning for state bucket | `bool` | `true` | no |
| environment | Environment name (dev, staging, prod) | `string` | `"dev"` | no |
| create_workload_identities | Create service accounts for workload identity | `bool` | `true` | no |
| billing_account | GCP billing account ID (optional) | `string` | `""` | no |
| labels | Labels to apply to all resources | `map(string)` | `{managed-by="terraform", project="observability-demo"}` | no |

## Outputs

| Name | Description |
|------|-------------|
| project_id | The GCP project ID |
| region | The primary GCP region |
| terraform_service_account_email | Email address of the Terraform service account |
| terraform_service_account_id | The service account ID for Terraform |
| terraform_service_account_name | Fully-qualified name of the Terraform service account |
| state_bucket_name | Name of the GCS bucket for Terraform state |
| state_bucket_url | URL of the Terraform state bucket |
| state_bucket_self_link | Self-link of the Terraform state bucket |
| otel_service_account_email | Email address of the OpenTelemetry collector SA |
| otel_service_account_id | The service account ID for OpenTelemetry collector |
| microservices_service_account_email | Email address of the microservices demo SA |
| microservices_service_account_id | The service account ID for microservices demo |
| enabled_apis | List of enabled GCP APIs |
| state_prefix | Prefix for Terraform state files |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| google | ~> 5.0 |

## Security Considerations

1. **Least Privilege**: Service accounts have minimal permissions required
2. **No Keys**: Uses Workload Identity (no service account key files)
3. **State Security**: State bucket uses uniform bucket-level access
4. **Versioning**: Enabled for state recovery
5. **Encryption**: Google-managed encryption for all data

## Example: Complete Setup

```hcl
# Configure the Google provider
provider "google" {
  project = "my-observ-demo"
  region  = "us-central1"
}

# Set up the project foundation
module "project_setup" {
  source = "./modules/gcp/project-setup"

  project_id        = "my-observ-demo"
  region            = "us-central1"
  state_bucket_name = "my-observ-demo-terraform-state"
  environment       = "dev"
  billing_account   = "012345-6789AB-CDEF01"

  create_workload_identities = true

  labels = {
    managed-by  = "terraform"
    project     = "observability-demo"
    environment = "dev"
    team        = "platform"
  }
}

# Output the state bucket for backend configuration
output "state_bucket" {
  value = module.project_setup.state_bucket_name
}

# Output service account emails for other modules
output "service_accounts" {
  value = {
    terraform     = module.project_setup.terraform_service_account_email
    otel          = module.project_setup.otel_service_account_email
    microservices = module.project_setup.microservices_service_account_email
  }
}
```

## Post-Setup Configuration

After applying this module, configure your Terraform backend:

```hcl
terraform {
  backend "gcs" {
    bucket = "my-observ-demo-terraform-state"
    prefix = "terraform/state"
  }
}
```

## Troubleshooting

### API Enablement Timeouts
If you encounter timeouts when enabling APIs, increase the timeout:

```hcl
  timeouts {
    create = "30m"
    update = "40m"
  }
```

### Permission Errors
Ensure you have the following permissions to run this module:
- `roles/resourcemanager.projectIamAdmin`
- `roles/iam.serviceAccountAdmin`
- `roles/storage.admin`
- `roles/serviceusage.serviceUsageAdmin`

### Billing Account Required
Some APIs require an active billing account. Ensure your project has billing enabled.

## License

MIT License - see root LICENSE file for details.

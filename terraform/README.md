# GCP Observability Demo - Terraform Infrastructure

This directory contains Terraform infrastructure as code (IaC) for deploying a complete, production-ready observability demo platform on Google Cloud Platform.

## Architecture Overview

The infrastructure is organized into modular components for reusability, maintainability, and cloud-agnostic design:

```
Root Module (main.tf)
├── project-setup     → GCP APIs, service accounts, Terraform state bucket
├── vpc-network       → VPC, subnets, Cloud NAT, firewalls
├── gke-cluster       → GKE Autopilot cluster with Workload Identity
├── iap-config        → Identity-Aware Proxy for secure access
├── monitoring        → Cloud Monitoring alerts and dashboards
└── budget-alerts     → Cost monitoring and budget tracking
```

### Key Features

- **GKE Autopilot**: Fully managed Kubernetes with pay-per-pod pricing (~60% cost savings)
- **Private Cluster**: No external IPs on nodes, Cloud NAT for egress
- **Workload Identity**: Secure pod authentication without service account keys
- **Identity-Aware Proxy (IAP)**: Zero-trust access without VPN
- **Comprehensive Monitoring**: Alerts for health, performance, and cost
- **Budget Controls**: Multi-threshold alerts with Pub/Sub integration
- **Security Best Practices**: Defense-in-depth with network policies and Cloud Armor

## Prerequisites

### Required Tools

- **Terraform** >= 1.6.0 ([Install](https://developer.hashicorp.com/terraform/downloads))
- **gcloud CLI** >= 450.0.0 ([Install](https://cloud.google.com/sdk/docs/install))
- **kubectl** >= 1.28.0 ([Install](https://kubernetes.io/docs/tasks/tools/))

### GCP Requirements

1. **GCP Project**: Create or use existing project
2. **Billing Account**: Active billing account linked to project
3. **Permissions**: User must have `roles/owner` or equivalent permissions:
   - `roles/compute.admin`
   - `roles/container.admin`
   - `roles/iam.serviceAccountAdmin`
   - `roles/resourcemanager.projectIamAdmin`
   - `roles/serviceusage.serviceUsageAdmin`

### Verify Prerequisites

```bash
# Check tool versions
terraform version  # Should be >= 1.6.0
gcloud version     # Should be >= 450.0.0
kubectl version --client  # Should be >= 1.28.0

# Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Set project
gcloud config set project YOUR_PROJECT_ID

# Verify permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:$(gcloud config get-value account)"
```

## Quick Start

### 1. Configure Variables

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Minimum required variables:**
```hcl
project_id         = "my-observ-demo-project"
billing_account    = "012345-6789AB-CDEF01"
region             = "us-central1"
notification_email = "your-email@example.com"
```

### 2. Initialize Terraform

```bash
# Initialize Terraform (download providers, setup modules)
terraform init

# Validate configuration
terraform validate

# Format configuration files
terraform fmt -recursive
```

### 3. Plan Deployment

```bash
# Preview infrastructure changes
terraform plan -out=tfplan

# Review the plan carefully before applying
```

### 4. Deploy Infrastructure

```bash
# Apply the plan
terraform apply tfplan

# Or apply directly (will prompt for confirmation)
terraform apply

# Deployment takes ~45-60 minutes
```

### 5. Configure State Backend (After First Apply)

After the first successful apply, migrate state to GCS:

```bash
# Copy backend configuration template
cp backend.tf.template backend.tf

# Edit backend.tf and replace REPLACE_WITH_STATE_BUCKET_NAME
# with the actual bucket name from terraform output
nano backend.tf

# Migrate state to GCS
terraform init -migrate-state

# Confirm migration when prompted
```

### 6. Access the Cluster

```bash
# Get kubectl credentials (command from terraform output)
gcloud container clusters get-credentials CLUSTER_NAME \
  --region REGION \
  --project PROJECT_ID

# Verify access
kubectl get nodes
kubectl get namespaces

# View cluster info
kubectl cluster-info
```

## Module Details

### 1. Project Setup Module

**Location**: [modules/gcp/project-setup](modules/gcp/project-setup)

**Purpose**: Foundation setup - enables APIs, creates service accounts, configures Terraform state storage

**Resources Created**:
- 12 required GCP APIs
- Terraform automation service account
- OpenTelemetry service account (with Workload Identity)
- Microservices demo service account (with Workload Identity)
- GCS bucket for Terraform state (versioned, lifecycle policies)

**Key Outputs**:
- Service account emails
- State bucket name
- Enabled APIs list

### 2. VPC Network Module

**Location**: [modules/gcp/vpc-network](modules/gcp/vpc-network)

**Purpose**: Private networking with Cloud NAT for secure, cost-optimized egress

**Resources Created**:
- VPC network (custom mode)
- GKE subnet with secondary IP ranges (pods, services)
- Cloud Router and Cloud NAT
- Firewall rules (allow internal, health checks, IAP; deny-all default)
- Optional: Static IP for load balancer

**IP Allocation**:
- Node CIDR: `10.0.0.0/20` (4,091 IPs)
- Pod CIDR: `10.4.0.0/14` (262,144 IPs)
- Service CIDR: `10.8.0.0/20` (4,091 IPs)

**Security Features**:
- Private Google Access enabled
- Flow logs (optional, for network troubleshooting)
- Minimal firewall rules (deny-all default)

### 3. GKE Cluster Module

**Location**: [modules/gcp/gke-cluster](modules/gcp/gke-cluster)

**Purpose**: Production-ready GKE Autopilot cluster with security best practices

**Resources Created**:
- GKE Autopilot cluster (regional or zonal)
- Workload Identity configuration
- Workload Identity bindings for OpenTelemetry and Microservices
- Optional: Private DNS zone
- Optional: Kubeconfig file generation

**Key Features**:
- **Autopilot Mode**: Fully managed, pay-per-pod pricing
- **Private Nodes**: No external IPs (master endpoint optionally private)
- **Workload Identity**: Secure service account binding for pods
- **Managed Prometheus**: GKE-managed Prometheus for metrics
- **Security Posture**: Vulnerability scanning and policy enforcement
- **Vertical Pod Autoscaling**: Right-size pod resources automatically
- **Release Channel**: Automatic version upgrades (REGULAR by default)

**Cost Optimization**:
- Autopilot eliminates node management overhead
- VPA right-sizes resources
- Resource quotas prevent runaway costs

### 4. IAP Configuration Module

**Location**: [modules/gcp/iap-config](modules/gcp/iap-config)

**Purpose**: Zero-trust access to applications without VPN

**Resources Created**:
- IAP OAuth brand (consent screen)
- IAP OAuth client credentials
- IAM bindings for authorized users
- Firewall rule for IAP IP range
- Optional: Static IP, SSL certificate, HTTPS proxy
- Optional: Cloud Armor security policy with rate limiting

**Security Features**:
- Identity-based access control
- No VPN required (reduces cost and complexity)
- Rate limiting (default: 1000 req/min)
- Geo-blocking (optional)
- DDoS protection via Cloud Armor

**Access Control**:
```hcl
iap_users = [
  "user:admin@example.com",
  "group:sre-team@example.com",
  "serviceAccount:automation@project.iam.gserviceaccount.com"
]
```

### 5. Monitoring Module

**Location**: [modules/gcp/monitoring](modules/gcp/monitoring)

**Purpose**: Comprehensive alerting and dashboards for operational visibility

**Resources Created**:
- Notification channels (Email, Slack, PagerDuty)
- Alert policies:
  - GKE cluster health
  - Pod crash loops and OOM kills
  - High error rates
  - Resource exhaustion (CPU, memory)
  - Deployment failures
  - Load balancer errors
- Dashboards (overview, GKE metrics)
- Optional: Uptime checks

**Alert Thresholds** (customizable):
- CPU: 80%
- Memory: 85%
- Error Rate: 5 errors/second
- Pod Restarts: 3 in 5 minutes

**Notification Channels**:
- Email: Instant alerts to inbox
- Slack: Webhook integration for team notifications
- PagerDuty: Escalation for critical alerts

### 6. Budget Alerts Module

**Location**: [modules/gcp/budget-alerts](modules/gcp/budget-alerts)

**Purpose**: Cost monitoring with multi-threshold alerts

**Resources Created**:
- Cloud Billing Budget
- Pub/Sub topic for budget notifications
- Cloud Monitoring alert for budget exceeded
- Optional: Pub/Sub subscription for programmatic handling
- Optional: Cloud Function for custom alert logic
- Optional: Log-based cost metric

**Default Thresholds**:
- 50% of budget (current spend)
- 75% of budget (current spend)
- 90% of budget (current spend)
- 100% of budget (current spend)
- 100% of budget (forecasted spend)

**Integration**:
- Email notifications
- Slack webhook
- Pub/Sub for automation (e.g., auto-shutdown)

## Deployment Workflow

### Phase 1: Prerequisites Validation (5 min)

```bash
# Verify tools
terraform version
gcloud version
kubectl version --client

# Authenticate
gcloud auth login
gcloud auth application-default login

# Set project
gcloud config set project YOUR_PROJECT_ID
```

### Phase 2: Configuration (5 min)

```bash
# Configure variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars

# Review configuration
terraform plan
```

### Phase 3: Infrastructure Deployment (45-60 min)

```bash
# Deploy infrastructure
terraform apply

# Modules deploy in sequence:
# 1. project-setup      (~10 min) - APIs, service accounts
# 2. vpc-network        (~5 min)  - VPC, subnets, NAT
# 3. gke-cluster        (~30 min) - GKE Autopilot cluster
# 4. iap-config         (~5 min)  - IAP configuration
# 5. monitoring         (~3 min)  - Alerts, dashboards
# 6. budget-alerts      (~2 min)  - Budget configuration
```

### Phase 4: State Migration (2 min)

```bash
# After first successful apply
cp backend.tf.template backend.tf
# Edit backend.tf with actual bucket name
terraform init -migrate-state
```

### Phase 5: Access Configuration (5 min)

```bash
# Get cluster credentials
gcloud container clusters get-credentials CLUSTER_NAME \
  --region REGION --project PROJECT_ID

# Verify access
kubectl get nodes

# Configure IAP users (if enabled)
gcloud iap web add-iam-policy-binding \
  --member=user:EMAIL \
  --role=roles/iap.httpsResourceAccessor
```

## Cost Optimization

### Estimated Monthly Costs (24/7 Operation)

| Component | Configuration | Cost |
|-----------|---------------|------|
| GKE Autopilot | 2 vCPU, 4GB RAM | $25-30 |
| Cloud Load Balancing | 2 forwarding rules | $18-22 |
| Cloud Trace | <1M spans | $5-10 |
| Cloud Monitoring | Basic metrics | $5-8 |
| Cloud Logging | Filtered logs | $2-5 |
| Networking | Minimal egress | <$1 |
| **TOTAL** | | **$45-71** |

### Cost Reduction Strategies

#### 1. Scale to Zero (Immediate)
```bash
# Scale all deployments to zero
kubectl scale deployment --all --replicas=0 -n opentelemetry
kubectl scale deployment --all --replicas=0 -n microservices-demo

# Cost: ~$18-25/month (load balancer + minimal monitoring)
```

#### 2. Shutdown Non-Essential Resources
```bash
# Disable monitoring (keep alerts)
# Reduce logging (errors only)
# Sample traces at 10% instead of 100%
```

#### 3. Full Teardown (When Not Needed)
```bash
terraform destroy

# Cost: $0/month
# Redeploy anytime: terraform apply (~45 min)
```

#### 4. Use Zonal Cluster (Lower Cost)
```hcl
regional_cluster = false  # Saves ~30% on cluster costs
zone = "us-central1-a"
```

#### 5. Optimize Resource Quotas
```yaml
# Set resource limits in Kubernetes manifests
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi
```

## Security Best Practices

### Defense-in-Depth Architecture

#### Layer 1: Identity & Access
- ✅ Service accounts with minimal permissions
- ✅ Workload Identity (no service account keys)
- ✅ IAP for zero-trust access
- ✅ User authentication via Google Identity

#### Layer 2: Network Security
- ✅ Private GKE cluster (no node public IPs)
- ✅ VPC with minimal CIDR ranges
- ✅ Cloud NAT for egress (no direct internet)
- ✅ Firewall rules (deny-all default)

#### Layer 3: Application Security
- ✅ Container security scanning (optional Binary Authorization)
- ✅ Pod Security Standards enforcement
- ✅ Kubernetes Network Policies
- ✅ Resource quotas and limits

#### Layer 4: Data Security
- ✅ Encryption at rest (GCS, persistent volumes)
- ✅ Encryption in transit (TLS everywhere)
- ✅ Secret management (Google Secret Manager)
- ✅ Audit logging (Cloud Audit Logs)

### Recommended IAM Roles

**Terraform Service Account**:
```
roles/compute.admin
roles/container.admin
roles/iam.serviceAccountAdmin
roles/resourcemanager.projectIamAdmin
roles/serviceusage.serviceUsageAdmin
```

**OpenTelemetry Service Account**:
```
roles/cloudtrace.agent
roles/monitoring.metricWriter
roles/logging.logWriter
```

**Microservices Demo Service Account**:
```
roles/cloudtrace.agent
roles/monitoring.metricWriter
roles/logging.logWriter
```

## Troubleshooting

### Common Issues

#### 1. API Not Enabled
**Error**: `API [SERVICE] is not enabled for project [PROJECT]`

**Solution**:
```bash
# Enable API manually
gcloud services enable SERVICE.googleapis.com --project=PROJECT_ID

# Or wait for project-setup module to enable (first deployment only)
```

#### 2. Insufficient Permissions
**Error**: `Permission denied on resource [RESOURCE]`

**Solution**:
```bash
# Verify current permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:$(gcloud config get-value account)"

# Request roles/owner or specific roles from project admin
```

#### 3. Quota Exceeded
**Error**: `Quota exceeded for quota metric [METRIC]`

**Solution**:
```bash
# Check quotas
gcloud compute project-info describe --project=PROJECT_ID

# Request quota increase
# https://console.cloud.google.com/iam-admin/quotas
```

#### 4. Cluster Creation Timeout
**Error**: `Timeout waiting for cluster to be ready`

**Solution**:
```bash
# Check cluster status
gcloud container clusters describe CLUSTER_NAME \
  --region=REGION --project=PROJECT_ID

# If stuck, may need to destroy and recreate
terraform destroy -target=module.gke_cluster
terraform apply
```

#### 5. Backend Initialization Failed
**Error**: `Backend initialization required`

**Solution**:
```bash
# Reconfigure backend
terraform init -reconfigure

# Or migrate state
terraform init -migrate-state
```

### Debugging Tips

**Enable Terraform Debug Logging**:
```bash
export TF_LOG=DEBUG
terraform apply
```

**Check GKE Cluster Logs**:
```bash
gcloud container clusters get-credentials CLUSTER_NAME \
  --region=REGION --project=PROJECT_ID

kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

**Verify Network Connectivity**:
```bash
# Test from Cloud Shell (allowed by default)
gcloud container clusters get-credentials CLUSTER_NAME \
  --region=REGION --project=PROJECT_ID

kubectl run test --image=busybox --rm -it --restart=Never -- sh
# Inside pod:
ping -c 3 google.com
nslookup kubernetes.default.svc.cluster.local
```

## Advanced Configuration

### Multi-Environment Setup

Create environment-specific variable files:

```bash
terraform/
├── environments/
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── prod.tfvars
```

**Deploy to specific environment**:
```bash
terraform apply -var-file=environments/dev.tfvars
```

### Custom Module Configuration

Override module defaults:

```hcl
# main.tf
module "gke_cluster" {
  source = "./modules/gcp/gke-cluster"

  # Override defaults
  cluster_name                    = "my-custom-cluster"
  regional_cluster                = false
  zone                            = "us-west1-a"
  enable_managed_prometheus       = false
  deletion_protection             = true
}
```

### Integrate with Existing Infrastructure

```hcl
# Use existing VPC
module "gke_cluster" {
  source = "./modules/gcp/gke-cluster"

  network_name      = "existing-vpc"
  subnetwork_name   = "existing-subnet"
  pods_range_name   = "existing-pods-range"
  services_range_name = "existing-services-range"
}
```

## Outputs

After deployment, Terraform provides comprehensive outputs:

```bash
# View all outputs
terraform output

# View specific output
terraform output cluster_name

# View sensitive output
terraform output -raw cluster_ca_certificate

# Export to JSON
terraform output -json > outputs.json
```

**Key Outputs**:
- `cluster_name`: GKE cluster name
- `cluster_endpoint`: Kubernetes API endpoint
- `kubectl_command`: Command to configure kubectl
- `access_urls`: Console links (GKE, Monitoring, Trace, Billing)
- `deployment_summary`: Complete deployment information
- `next_steps`: Post-deployment instructions

## Next Steps

After successful infrastructure deployment:

1. **Configure kubectl**: Use the command from `terraform output kubectl_command`
2. **Deploy Applications**: Deploy OpenTelemetry and Microservices demos
3. **Generate Traffic**: Use traffic generation scripts
4. **Configure Monitoring**: View dashboards and test alerts
5. **Set Up IAP Access**: Add authorized users

See [../README.md](../README.md) for application deployment instructions.

## Support

- **Issues**: [GitHub Issues](https://github.com/YOUR_ORG/observ-demo/issues)
- **Documentation**: [docs/](../docs/)
- **Examples**: [examples/](../examples/)

## License

MIT License - See [LICENSE](../LICENSE) for details

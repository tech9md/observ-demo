# Infrastructure Fix - Switch to Standard GKE

## Problem Summary

The GKE Autopilot cluster had multiple issues preventing proper observability:

### Problem 1: Disk Quota Exceeded
- Autopilot uses 100GB boot disk per node (not configurable)
- Regional cluster = 3 zones × 100GB = 300GB minimum
- Project quota: 400GB total → only 100GB remaining
- Could not scale nodes for kubeletstats collector

### Problem 2: Missing IAM Role
- Node service account missing `roles/container.defaultNodeServiceAccount`
- Caused degraded logging/monitoring and HPA issues

### Problem 3: Autopilot Restrictions
- Cannot use hostNetwork (needed for some metrics collectors)
- Cannot customize boot disk size
- Must be regional (cannot use zonal to save quota)
- Resource minimums enforced (250m CPU, 512Mi memory)

## Solution: Switch to Standard GKE

Converted from GKE Autopilot to Standard GKE with:
- **Zonal deployment** (1 zone instead of 3) → 50GB vs 90GB disk usage
- **50GB boot disk** per node (instead of 100GB default)
- **e2-standard-2** machine type (2 vCPU, 8GB RAM)
- **Autoscaling** from 1-5 nodes
- **pd-standard** disk type (cheaper than SSD)

## Changes Made

### File 1: `terraform/modules/gcp/gke-cluster/main.tf`
Complete rewrite from Autopilot to Standard GKE:

```hcl
# Standard GKE cluster (not Autopilot)
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.regional_cluster ? var.region : var.zone

  # Standard GKE configuration
  remove_default_node_pool = true
  initial_node_count       = 1

  # Private cluster
  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

# Node pool with smaller boot disk
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  cluster    = google_container_cluster.primary.name

  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 30  # CRITICAL: Reduced from 100GB
    disk_type    = "pd-standard"

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }
}
```

### File 2: `terraform/variables.tf`
Changed to zonal deployment:

```hcl
variable "regional_cluster" {
  description = "Create a regional cluster (true) or zonal cluster (false). Zonal uses less disk quota."
  type        = bool
  default     = false  # Zonal cluster to save disk quota (50GB vs 90GB for regional)
}
```

### File 3: `terraform/modules/gcp/project-setup/main.tf`
Added IAM role for node service account:

```hcl
resource "google_project_iam_member" "gke_node_service_account" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}
```

## Disk Quota Comparison

| Configuration | Nodes | Boot Disk | Total Disk |
|---------------|-------|-----------|------------|
| Autopilot Regional (before) | 3 | 100GB | 300GB |
| Standard Zonal (after) | 1-5 | 50GB | 30-150GB |

**Savings:** 150-270GB of disk quota freed up!

## Deployment

### ⚠️ IMPORTANT: Cluster Will Be Recreated

Switching from Autopilot to Standard **requires cluster recreation**:
- All existing workloads will be deleted
- Kubernetes applications must be redeployed
- Cluster endpoint/credentials will change

### Option 1: GitHub Actions (Recommended)

1. Commit and push the changes:
   ```bash
   git add terraform/
   git add kubernetes/opentelemetry/values-kubeletstats-final.yaml
   git add INFRASTRUCTURE_FIX.md
   git commit -m "Switch from Autopilot to Standard GKE to fix disk quota

- Convert GKE from Autopilot to Standard mode
- Use zonal deployment (1 zone instead of 3)
- Reduce boot disk from 100GB to 50GB
- Add IAM role for GKE node service account
- Add kubeletstats collector configuration"
   git push origin main
   ```

2. Run the GitHub Actions **deploy** workflow:
   - Go to GitHub → Actions → deploy workflow
   - Click "Run workflow"
   - Select branch: `main`
   - Click "Run workflow"

3. Monitor the deployment:
   - Cluster recreation takes ~15-20 minutes
   - Kubernetes apps will be redeployed automatically

### Option 2: Local Terraform

```bash
cd terraform
terraform init
terraform plan  # Review changes - will show cluster replacement
terraform apply # Apply changes
```

## Post-Deployment Steps

After the cluster is recreated:

### 1. Get cluster credentials
```bash
gcloud container clusters get-credentials PROJECT_ID-gke --zone us-central1-a --project PROJECT_ID
```

### 2. Verify cluster is healthy
```bash
kubectl get nodes
kubectl get pods -A
```

### 3. Deploy kubeletstats collector (for actual CPU/memory metrics)
```bash
helm install otel-kubeletstats opentelemetry-collector \
  --repo https://open-telemetry.github.io/opentelemetry-helm-charts \
  --namespace opentelemetry \
  --values kubernetes/opentelemetry/values-kubeletstats-final.yaml \
  --wait
```

### 4. Verify metrics collection
```bash
# Check kubeletstats pods
kubectl get pods -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector

# Check metrics are being collected
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector --tail=50
```

### 5. Access dashboards
```bash
# Grafana (dashboards)
kubectl port-forward -n observability svc/grafana 3000:3000

# Prometheus (metrics)
kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090

# Jaeger (traces)
kubectl port-forward -n observability svc/jaeger-query 16686:16686

# Microservices Demo (generate traffic)
kubectl port-forward -n microservices-demo svc/frontend 8080:80
```

## Expected Results

After deployment:

✅ **Disk Quota Fixed:**
- Using only 30-150GB instead of 300GB
- Room for additional nodes and workloads

✅ **IAM Role Applied:**
- Node service account has required permissions
- Logging and monitoring fully functional
- HPA and autoscaler work correctly

✅ **Kubeletstats Collector:**
- Collecting actual CPU/memory/network usage metrics
- Metrics exported to Prometheus on port 8889
- Grafana dashboards show real data

## Rollback

To revert to Autopilot (not recommended due to quota issues):

1. Change `regional_cluster` back to `true` in variables.tf
2. Restore the Autopilot configuration in main.tf
3. Run `terraform apply`

Note: This will recreate the cluster again and quota issues will return.

## Benefits of Standard GKE

| Feature | Autopilot | Standard |
|---------|-----------|----------|
| Boot disk size | 100GB (fixed) | 50GB (configurable) |
| Zonal cluster | ❌ Not allowed | ✅ Supported |
| hostNetwork | ❌ Blocked | ✅ Allowed |
| Resource minimums | 250m/512Mi enforced | ✅ Flexible |
| Node customization | ❌ Limited | ✅ Full control |
| Cost | Higher (managed) | Lower (self-managed) |

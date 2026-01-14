# Infrastructure Fix - IAM Roles

## Problem

The GKE Autopilot cluster was missing critical IAM role assignments for the node service account, causing:
- Degraded logging and monitoring
- HPA (Horizontal Pod Autoscaler) issues
- Inability to scale up nodes
- Webhook validation failures

## Solution

Added IAM role binding in Terraform to grant `roles/container.defaultNodeServiceAccount` to the GKE node service account (default Compute Engine service account).

## Changes Made

### File: `terraform/modules/gcp/project-setup/main.tf`

Added:
```hcl
# Data source to get project number
data "google_project" "project" {
  project_id = var.project_id
}

# Grant GKE node service account the required default role
resource "google_project_iam_member" "gke_node_service_account" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"

  depends_on = [google_project_service.required_apis]
}
```

## Deployment Options

### Option 1: GitHub Actions (Recommended)

1. Commit and push the changes:
   ```bash
   git add terraform/modules/gcp/project-setup/main.tf
   git commit -m "Fix: Add missing IAM role for GKE node service account"
   git push origin main
   ```

2. Run the GitHub Actions **deploy** workflow:
   - Go to GitHub → Actions → deploy workflow
   - Click "Run workflow"
   - Select branch: `main`
   - Click "Run workflow"

3. Monitor the deployment:
   - Infrastructure updates should complete in ~5-10 minutes
   - No cluster recreation required (IAM change only)

### Option 2: Local Terraform (If you have credentials)

```bash
cd terraform
terraform init
terraform plan  # Review changes
terraform apply # Apply changes
```

## Expected Results

After deployment:

✅ **GKE Notifications Resolved:**
- "Node service account missing roles" warning will disappear
- Logging and monitoring will be fully functional
- Cluster autoscaler can scale up nodes
- HPA will work correctly

✅ **Kubeletstats Deployment:**
After IAM fix, the cluster should have capacity to deploy the kubeletstats collector:
```bash
helm install otel-kubeletstats opentelemetry-collector \
  --repo https://open-telemetry.github.io/opentelemetry-helm-charts \
  --namespace opentelemetry \
  --values kubernetes/opentelemetry/values-kubeletstats-final.yaml \
  --wait
```

## Verification

After deployment, verify the fix:

1. **Check IAM role:**
   ```bash
   PROJECT_NUMBER=$(gcloud projects describe $(gcloud config get-value project) --format="value(projectNumber)")
   gcloud projects get-iam-policy $(gcloud config get-value project) \
     --flatten="bindings[].members" \
     --filter="bindings.members:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
     --format="table(bindings.role)"
   ```

   Should show: `roles/container.defaultNodeServiceAccount`

2. **Check GKE notifications:**
   - Go to GCP Console → Kubernetes Engine → Clusters
   - Click on your cluster
   - Notifications panel should be clear

3. **Test node scaling:**
   ```bash
   kubectl get nodes
   # Should show nodes can scale when needed
   ```

## Next Steps

Once IAM is fixed:

1. Deploy kubeletstats collector (see above)
2. Verify metrics collection
3. Update Grafana dashboards with actual usage metrics
4. Create ServiceMonitor for Prometheus scraping

## Rollback

If issues occur, you can remove the IAM binding:

```bash
PROJECT_NUMBER=$(gcloud projects describe $(gcloud config get-value project) --format="value(projectNumber)")
gcloud projects remove-iam-policy-binding $(gcloud config get-value project) \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/container.defaultNodeServiceAccount"
```

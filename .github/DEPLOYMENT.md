# Deployment Guide - GitHub Actions

This guide explains how to deploy the Observability Demo using GitHub Actions for fully automated end-to-end deployment.

## Overview

The GitHub Actions pipeline provides:
- **Deploy**: Full infrastructure + applications deployment
- **Stop**: Scale all pods to zero (saves costs, keeps infrastructure)
- **Start**: Scale pods back up from stopped state
- **Destroy**: Remove all resources completely

## Prerequisites

### 1. GCP Account Setup

You need:
- A GCP account with billing enabled
- Owner or Editor access to a GCP project
- A billing account ID

### 2. Fork/Clone the Repository

```bash
# Clone to your GitHub account
git clone https://github.com/your-org/observ-demo.git
cd observ-demo
git remote set-url origin https://github.com/YOUR_USERNAME/observ-demo.git
git push -u origin main
```

## Setup Steps

### Step 1: Create GCP Project (if needed)

```bash
# Install gcloud CLI if not already installed
# https://cloud.google.com/sdk/docs/install

# Login
gcloud auth login

# Create project
gcloud projects create YOUR-PROJECT-ID --name="Observability Demo"

# Link billing (get your billing account ID first)
gcloud billing accounts list
gcloud billing projects link YOUR-PROJECT-ID --billing-account=BILLING_ACCOUNT_ID
```

### Step 2: Create Service Account for GitHub Actions

```bash
# Set your project
gcloud config set project YOUR-PROJECT-ID

# Create service account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions" \
  --description="Service account for GitHub Actions CI/CD"

# Grant required roles
SA_EMAIL="github-actions@YOUR-PROJECT-ID.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding YOUR-PROJECT-ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/owner"

# Create and download key
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=$SA_EMAIL

echo "Key saved to github-actions-key.json"
```

### Step 3: Create Terraform State Bucket

```bash
# Create bucket for Terraform state
gsutil mb -p YOUR-PROJECT-ID -l us-central1 -b on gs://YOUR-PROJECT-ID-tfstate

# Enable versioning
gsutil versioning set on gs://YOUR-PROJECT-ID-tfstate
```

### Step 4: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

| Secret Name | Value |
|-------------|-------|
| `GCP_SA_KEY` | Contents of `github-actions-key.json` (the entire JSON file) |
| `GCP_PROJECT_ID` | Your GCP project ID (e.g., `observ-demo-12345`) |
| `GCP_BILLING_ACCOUNT` | Your billing account ID (e.g., `012345-6789AB-CDEF01`) |

**To get the key contents:**
```bash
cat github-actions-key.json
# Copy the entire output and paste as the GCP_SA_KEY secret value
```

### Step 5: Enable Required APIs

You can either:

**Option A: Run the Setup workflow**
1. Go to Actions tab in your GitHub repo
2. Click "Initial GCP Setup" workflow
3. Click "Run workflow"
4. Enter your project ID and region
5. Click "Run workflow"

**Option B: Run manually**
```bash
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  servicenetworking.googleapis.com \
  iap.googleapis.com \
  billingbudgets.googleapis.com \
  --project=YOUR-PROJECT-ID
```

## Running Workflows

### Deploy Everything

1. Go to **Actions** → **Deploy Observability Demo**
2. Click **Run workflow**
3. Configure options:
   - **Action**: `deploy`
   - **Environment**: `demo`
   - **Region**: `us-central1` (or your preferred region)
   - **Auto-approve**: `true` (for unattended deployment)
4. Click **Run workflow**

**Deployment takes approximately 30-45 minutes:**
- Terraform infrastructure: ~15-20 minutes
- Observability stack: ~5-10 minutes
- OpenTelemetry Collector: ~2-3 minutes
- Microservices Demo: ~5-10 minutes

### Stop (Save Costs)

To pause the demo without destroying infrastructure:

1. Go to **Actions** → **Deploy Observability Demo**
2. Click **Run workflow**
3. Select **Action**: `stop`
4. Click **Run workflow**

This scales all deployments to zero replicas. GKE Autopilot will automatically scale down nodes, reducing costs to near zero (you only pay for the control plane ~$70/month).

### Start (Resume)

To resume from stopped state:

1. Go to **Actions** → **Deploy Observability Demo**
2. Click **Run workflow**
3. Select **Action**: `start`
4. Click **Run workflow**

Pods will start within 2-5 minutes.

### Destroy Everything

To remove all resources and stop all billing:

1. Go to **Actions** → **Deploy Observability Demo**
2. Click **Run workflow**
3. Select **Action**: `destroy`
4. Click **Run workflow**

**Warning**: This deletes all resources including data. Terraform state is preserved in GCS for potential redeployment.

## Accessing the Stack After Deployment

After deployment completes, configure kubectl locally:

```bash
# Install gcloud CLI (if not installed)
# https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login

# Get cluster credentials
gcloud container clusters get-credentials observ-demo-cluster \
  --region us-central1 \
  --project YOUR-PROJECT-ID

# Verify connection
kubectl get nodes
kubectl get pods -A
```

### Port Forwarding to Access UIs

```bash
# Jaeger (Distributed Tracing)
kubectl port-forward -n observability svc/jaeger-query 16686:16686 &
# Access: http://localhost:16686

# Prometheus (Metrics)
kubectl port-forward -n observability svc/prometheus-server 9090:9090 &
# Access: http://localhost:9090

# Grafana (Dashboards)
kubectl port-forward -n observability svc/grafana 3000:3000 &
# Access: http://localhost:3000
# Credentials: admin / admin123

# Alertmanager
kubectl port-forward -n observability svc/prometheus-alertmanager 9093:9093 &
# Access: http://localhost:9093
```

## Cost Management

### Estimated Monthly Costs

| State | Approximate Cost |
|-------|------------------|
| **Running (24/7)** | $60-80/month |
| **Stopped** | $70-75/month (GKE control plane only) |
| **Destroyed** | $0/month (only Terraform state bucket ~$0.01) |

### Cost-Saving Strategies

1. **Stop when not in use**: Use the `stop` action overnight or on weekends
2. **Destroy for extended breaks**: Use `destroy` for holidays or breaks
3. **Use port-forwarding**: Avoid load balancers to save ~$20/month
4. **Reduce retention**: Lower Prometheus retention from 7d to 3d

## Troubleshooting

### Workflow Fails at Terraform Apply

**Issue**: Authentication or permission errors

**Solution**:
1. Verify `GCP_SA_KEY` secret contains the complete JSON
2. Ensure service account has `roles/owner` or required specific roles
3. Check that billing is linked to the project

### Workflow Fails at GKE Credentials

**Issue**: Cluster not found or connection refused

**Solution**:
1. Wait for Terraform to complete (GKE creation takes 10-15 minutes)
2. Verify cluster name matches `observ-demo-cluster`
3. Check the region matches your deployment

### Pods Not Starting

**Issue**: Pods stuck in Pending or CrashLoopBackOff

**Solution**:
```bash
# Check pod status
kubectl get pods -n observability
kubectl describe pod <pod-name> -n observability

# Check events
kubectl get events -n observability --sort-by='.lastTimestamp'
```

### Terraform State Lock

**Issue**: State is locked by another process

**Solution**:
```bash
# Force unlock (use with caution)
cd terraform
terraform force-unlock <LOCK_ID>
```

## Security Notes

- **Service Account Key**: Store securely, rotate periodically
- **GitHub Secrets**: Never commit secrets to the repository
- **Network Security**: The cluster uses private nodes with no public IPs
- **IAP Access**: Configure IAP for secure browser-based access

## Next Steps

After successful deployment:

1. **Generate traffic**: Use the traffic generator to create demo data
2. **Explore Jaeger**: View distributed traces
3. **Query Prometheus**: Run PromQL queries for metrics
4. **View Grafana dashboards**: Analyze Golden Signals and SLOs
5. **Configure alerts**: Set up Alertmanager notifications

For more details, see the main [README.md](../README.md).

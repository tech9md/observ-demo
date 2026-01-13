# GCP Observability Demo

A production-ready platform for deploying and managing observability demos on Google Cloud Platform (GCP) using **open-source tools** (Jaeger, Prometheus, Grafana) with OpenTelemetry.

**Perfect for:** SRE teams, DevOps engineers, and anyone learning observability practices with distributed tracing, metrics monitoring, and SLO tracking.

## Overview

This platform deploys a complete observability stack to GKE Autopilot:

- **OpenTelemetry Collector** - Vendor-agnostic telemetry pipeline (OTLP receiver)
- **Jaeger** - Distributed tracing backend with UI
- **Prometheus** - Time-series metrics database with alerting
- **Grafana** - Unified dashboards for metrics and traces
- **Google Microservices Demo** - 11 polyglot microservices generating real telemetry

## Architecture

```
+------------------------------------------------------------------+
|                     GKE Autopilot Cluster                         |
|                                                                   |
|  +------------------------+     +-----------------------------+   |
|  |  microservices-demo    |     |      observability          |   |
|  |  namespace             |     |      namespace              |   |
|  |                        |     |                             |   |
|  |  - frontend            |     |  +----------+  +----------+ |   |
|  |  - cartservice         |     |  |  Jaeger  |  |Prometheus| |   |
|  |  - checkoutservice     | OTLP|  |  (traces)|  | (metrics)| |   |
|  |  - currencyservice     +---->+  +----+-----+  +-----+----+ |   |
|  |  - emailservice        |     |       |              |      |   |
|  |  - paymentservice      |     |       +------+-------+      |   |
|  |  - productcatalog      |     |              |              |   |
|  |  - recommendationservice|    |        +-----v-----+        |   |
|  |  - shippingservice     |     |        |  Grafana  |        |   |
|  |  - adservice           |     |        |(dashboards)|       |   |
|  |  - redis-cart          |     |        +-----------+        |   |
|  +------------------------+     +-----------------------------+   |
|                                                                   |
|  +------------------------+                                       |
|  |    opentelemetry       |                                       |
|  |    namespace           |                                       |
|  |                        |                                       |
|  |  +------------------+  |                                       |
|  |  |   OpenTelemetry  |  |                                       |
|  |  |    Collector     |  |                                       |
|  |  +------------------+  |                                       |
|  +------------------------+                                       |
+------------------------------------------------------------------+
```

## Key Features

### Open Source Observability Stack
- **Jaeger** - CNCF graduated distributed tracing platform
- **Prometheus** - CNCF graduated monitoring and alerting toolkit
- **Grafana** - Industry-standard visualization platform
- **OpenTelemetry** - Vendor-neutral telemetry collection

### Cost-Optimized for Demos
- **GKE Autopilot** - Pay only for running pods (~$25-30/month base)
- **Minimal resources** - Optimized for 5-10 concurrent users
- **Stop/Start capability** - Scale to zero when not in use
- **Budget alerts** - Get notified before exceeding budget

### Production Best Practices
- **Private GKE cluster** - No public node IPs
- **Workload Identity** - No service account keys
- **Network policies** - Namespace isolation
- **SRE dashboards** - Golden Signals, SLO tracking

## Quick Start

### Prerequisites

1. **GCP Account** with billing enabled
2. **GitHub Account** with repository access
3. **Local tools** (for accessing the deployed stack):
   - [gcloud CLI](https://cloud.google.com/sdk/docs/install)
   - [kubectl](https://kubernetes.io/docs/tasks/tools/)

### Deployment via GitHub Actions

This project uses GitHub Actions for automated deployment. See the [Deployment Guide](.github/DEPLOYMENT.md) for detailed setup instructions.

#### 1. Fork/Clone the Repository

```bash
git clone https://github.com/YOUR_ORG/observ-demo.git
cd observ-demo
```

#### 2. Create GCP Service Account

```bash
# Set your project ID
export PROJECT_ID=your-project-id

# Create service account for GitHub Actions
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions" \
  --project=$PROJECT_ID

# Grant owner role (or specific roles for production)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/owner"

# Create key file
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=github-actions@$PROJECT_ID.iam.gserviceaccount.com
```

#### 3. Create Terraform State Bucket

```bash
gsutil mb -p $PROJECT_ID -l us-central1 -b on gs://$PROJECT_ID-tfstate
gsutil versioning set on gs://$PROJECT_ID-tfstate
```

#### 4. Configure GitHub Secrets

In your GitHub repository, go to **Settings > Secrets and variables > Actions** and add:

| Secret | Value |
|--------|-------|
| `GCP_SA_KEY` | Contents of `github-actions-key.json` |
| `GCP_PROJECT_ID` | Your GCP project ID |
| `GCP_BILLING_ACCOUNT` | Your billing account ID (format: `XXXXXX-XXXXXX-XXXXXX`) |

#### 5. Run the Deployment

1. Go to **Actions** tab in your GitHub repository
2. Select **Deploy Observability Demo**
3. Click **Run workflow**
4. Configure:
   - Action: `deploy`
   - Environment: `demo`
   - Region: `us-central1`
   - Auto-approve: `true`
5. Click **Run workflow**

Deployment takes approximately **30-45 minutes**.

### Accessing the Stack

After deployment completes, configure kubectl and access the UIs:

```bash
# Get cluster credentials
gcloud container clusters get-credentials $PROJECT_ID-gke \
  --region us-central1 \
  --project $PROJECT_ID

# Verify connection
kubectl get nodes
```

#### Port Forwarding (Recommended)

```bash
# Jaeger UI (Traces)
kubectl port-forward -n observability svc/jaeger-query 16686:16686
# Access: http://localhost:16686

# Prometheus (Metrics)
kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090
# Access: http://localhost:9090

# Alertmanager (Alerts)
kubectl port-forward -n observability svc/prometheus-kube-prometheus-alertmanager 9093:9093
# Access: http://localhost:9093

# Grafana (Dashboards)
kubectl port-forward -n observability svc/grafana 3000:3000
# Access: http://localhost:3000
# Credentials: admin / admin123

# Microservices Demo Frontend
kubectl port-forward -n microservices-demo svc/frontend 8080:80
# Access: http://localhost:8080
```

## Workflow Actions

The GitHub Actions workflow supports four actions:

| Action | Description | Use Case |
|--------|-------------|----------|
| `deploy` | Full infrastructure + applications | Initial setup or full redeploy |
| `stop` | Scale all pods to zero | Save costs overnight/weekends |
| `start` | Scale pods back up | Resume after stop |
| `destroy` | Remove all resources | Complete teardown |

### Cost Management

```bash
# Stop (scale to zero, keeps infrastructure)
# Run GitHub Action with action: stop
# Cost: ~$0/day (GKE Autopilot charges only for running pods)

# Start (resume from stopped state)
# Run GitHub Action with action: start
# Takes 2-5 minutes for pods to be ready

# Destroy (remove everything)
# Run GitHub Action with action: destroy
# Cost: $0 (only Terraform state bucket ~$0.01/month)
```

## Cost Breakdown

Monthly costs for 24/7 operation (GKE Autopilot, us-central1):

| Component | Resources | Monthly Cost |
|-----------|-----------|--------------|
| **GKE Autopilot** | | |
| Microservices Demo (10 services) | ~2.5 vCPU, 5Gi RAM | $40-50 |
| Observability Stack | ~1.5 vCPU, 3Gi RAM | $25-35 |
| OpenTelemetry Collector | 250m CPU, 512Mi RAM | $8-10 |
| **Storage** | | |
| Prometheus PVC | 5Gi SSD | $1-2 |
| Alertmanager PVC | 1Gi SSD | <$1 |
| Terraform State (GCS) | <1GB | <$1 |
| **TOTAL** | | **$75-100** |

### Cost Optimization Tips

1. **Use stop/start** - Scale to zero overnight and weekends
2. **Port-forwarding** - Avoid external load balancers ($18-22/month savings)
3. **Destroy when done** - Use destroy action for extended breaks
4. **Single region** - Deploy in one region to minimize egress costs

## Resource Requirements

**Important:** GKE Autopilot enforces minimum resource requirements:
- **Minimum per container**: 250m CPU, 512Mi memory
- **Maximum per container**: Varies by machine type

All components in this project are configured to meet these minimums.

## Project Structure

```
observ-demo/
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions deployment workflow
├── terraform/                   # Infrastructure as Code
│   ├── main.tf                 # Root module
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   └── modules/gcp/            # GCP-specific modules
│       ├── project-setup/      # APIs, service accounts
│       ├── vpc-network/        # VPC, subnets, NAT
│       ├── gke-cluster/        # GKE Autopilot cluster
│       ├── iap-config/         # Identity-Aware Proxy
│       ├── monitoring/         # Cloud Monitoring alerts
│       └── budget-alerts/      # Budget notifications
├── kubernetes/                  # Kubernetes manifests
│   ├── observability/          # Jaeger, Prometheus, Grafana
│   │   ├── jaeger-all-in-one.yaml
│   │   ├── prometheus-values.yaml
│   │   └── grafana.yaml
│   ├── opentelemetry/          # OpenTelemetry Collector
│   │   └── values-collector.yaml
│   └── microservices-demo/     # Google Microservices Demo
│       └── values-gcp.yaml
└── docs/                        # Additional documentation
```

## Observability Features

### Distributed Tracing (Jaeger)

- View end-to-end request traces across all microservices
- Analyze latency breakdowns per service
- Identify bottlenecks and errors
- Service dependency visualization

### Metrics (Prometheus)

Pre-configured recording rules for SLI tracking:
- `microservices:request_rate:1m` - Request rate per service
- `microservices:error_rate:1m` - Error rate per service
- `microservices:latency:p50/p95/p99` - Latency percentiles
- `microservices:availability:1h` - Service availability

### Alerting (Prometheus Alertmanager)

Pre-configured alerts for SLO violations:
- **HighErrorRate** - >5% error rate for 5 minutes
- **CriticalErrorRate** - >10% error rate for 2 minutes
- **HighLatencyP95** - >1s P95 latency for 5 minutes
- **HighLatencyP99** - >2s P99 latency for 5 minutes
- **LowAvailability** - <99% availability for 5 minutes
- **ServiceDown** - Service unavailable for 1 minute

### Dashboards (Grafana)

Pre-configured dashboards:
- **SRE Golden Signals** - Traffic, Errors, Latency, Saturation
- **SLO Tracking** - Availability, Error Rate, Latency targets
- **Error Budget** - Budget consumption over time

## Troubleshooting

### Pods in CrashLoopBackOff

```bash
# Check pod status
kubectl get pods -n <namespace>

# View pod logs
kubectl logs -n <namespace> <pod-name>

# Describe pod for events
kubectl describe pod -n <namespace> <pod-name>

# Common cause: Resource limits below GKE Autopilot minimums
# Solution: Ensure all containers have at least 250m CPU, 512Mi memory
```

### No Traces in Jaeger

```bash
# Check OpenTelemetry Collector logs
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector

# Verify Jaeger is receiving data
kubectl logs -n observability -l app=jaeger

# Check collector config
kubectl get configmap -n opentelemetry otel-collector-opentelemetry-collector -o yaml
```

### Prometheus Not Scraping Metrics

```bash
# Check Prometheus targets
kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check service monitors
kubectl get servicemonitors -A
```

### GitHub Actions Deployment Fails

1. **Terraform errors**: Check GCP_SA_KEY has correct permissions
2. **Helm timeouts**: GKE Autopilot pod scheduling can take 5-10 minutes
3. **API not enabled**: Run the deployment again; APIs enable asynchronously

## Security

### Implemented Security Features

- **Private GKE Cluster** - Nodes have no public IPs
- **Workload Identity** - Pods authenticate without service account keys
- **Network Policies** - Namespace isolation for traffic control
- **RBAC** - Kubernetes role-based access control
- **Pod Security** - Security contexts on all pods

### Credentials

| Component | Default Credentials |
|-----------|---------------------|
| Grafana | admin / admin123 |

**Note:** Change default passwords for any non-demo usage.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

This project uses these excellent open-source tools:

- [OpenTelemetry](https://opentelemetry.io/) - Observability framework
- [Jaeger](https://www.jaegertracing.io/) - Distributed tracing (CNCF)
- [Prometheus](https://prometheus.io/) - Monitoring and alerting (CNCF)
- [Grafana](https://grafana.com/) - Visualization platform
- [Google Microservices Demo](https://github.com/GoogleCloudPlatform/microservices-demo) - Sample application
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts) - Prometheus operator

## Support

- Open an issue in the repository
- Check the [Deployment Guide](.github/DEPLOYMENT.md)
- Review [Terraform documentation](terraform/README.md)

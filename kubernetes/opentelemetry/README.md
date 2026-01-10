# OpenTelemetry Demo - GKE Deployment

This directory contains Kubernetes manifests and configuration for deploying the [OpenTelemetry Demo](https://opentelemetry.io/docs/demo/) application to Google Kubernetes Engine (GKE) with GCP-native observability integration.

## Overview

The OpenTelemetry Demo is a microservices-based e-commerce application that demonstrates OpenTelemetry instrumentation across multiple languages and frameworks. This deployment is optimized for GKE with:

- **GCP-Native Exporters**: Cloud Trace, Cloud Monitoring, Cloud Logging
- **Workload Identity**: Secure authentication without service account keys
- **Cost Optimization**: Resource limits, sampling, autoscaling
- **Production Best Practices**: Network policies, pod security, monitoring

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenTelemetry Demo                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Frontend │  │   Cart   │  │ Product  │  │ Checkout │   │
│  │ (Next.js)│  │ (Redis)  │  │ Catalog  │  │  (Go)    │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │              │              │          │
│       └─────────────┴──────────────┴──────────────┘          │
│                          │                                   │
│                    ┌─────▼─────┐                            │
│                    │   OTEL    │                            │
│                    │ Collector │                            │
│                    └─────┬─────┘                            │
└──────────────────────────┼──────────────────────────────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
         ┌────▼────┐  ┌───▼───┐  ┌────▼────┐
         │  Cloud  │  │ Cloud │  │ Cloud   │
         │  Trace  │  │Monitor│  │ Logging │
         └─────────┘  └───────┘  └─────────┘
```

## Components

### Core Services

1. **Frontend** - Next.js web application
2. **Cart Service** - Shopping cart (Redis)
3. **Product Catalog Service** - Product inventory
4. **Checkout Service** - Order processing
5. **Payment Service** - Payment processing
6. **Shipping Service** - Shipping calculations
7. **Email Service** - Email notifications
8. **Recommendation Service** - Product recommendations
9. **Ad Service** - Advertisement serving
10. **Currency Service** - Currency conversion

### OpenTelemetry Collector

- **Receivers**: OTLP (gRPC, HTTP), Prometheus
- **Processors**: Batch, Memory Limiter, Resource Detection, Sampling
- **Exporters**: Google Cloud (Trace, Monitoring, Logging), Prometheus

## Prerequisites

- GKE cluster running with Workload Identity enabled
- Helm 3.x installed
- kubectl configured to access the cluster
- GCP service account with permissions:
  - `roles/cloudtrace.agent`
  - `roles/monitoring.metricWriter`
  - `roles/logging.logWriter`

## Quick Start

### 1. Configure Service Account

The OpenTelemetry Collector service account must be created and bound via Workload Identity:

```bash
# This is handled by the Terraform project-setup module
# Service account: otel-collector@PROJECT_ID.iam.gserviceaccount.com
```

### 2. Deploy Using Script

```bash
# Set project ID
export GCP_PROJECT_ID=your-project-id

# Make script executable
chmod +x deploy.sh

# Deploy
./deploy.sh
```

### 3. Deploy Using Helm Manually

```bash
# Add Helm repository
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Create namespace
kubectl create namespace opentelemetry

# Update values-gcp.yaml with your PROJECT_ID

# Install
helm upgrade --install otel-demo \
  open-telemetry/opentelemetry-demo \
  --namespace opentelemetry \
  --values values-gcp.yaml \
  --wait
```

## Configuration

### Resource Limits (Cost Optimized)

Default resource limits are set for cost efficiency:

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| Frontend | 100m | 128Mi | 200m | 256Mi |
| Collector | 200m | 512Mi | 500m | 1Gi |
| Services | 50-100m | 64-128Mi | 100-200m | 128-256Mi |

**Total estimated cost**: ~$15-20/month for baseline deployment

### Sampling Configuration

To reduce Cloud Trace costs, traces are sampled at **10%** by default:

```yaml
processors:
  probabilistic_sampler:
    sampling_percentage: 10.0
```

**To adjust sampling rate**, edit `values-gcp.yaml`:
- 100% (all traces): Best for demos, higher cost
- 10% (default): Balanced for production demos
- 1%: Minimal cost for long-running demos

### Autoscaling

Horizontal Pod Autoscaling (HPA) is enabled:

```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
```

## Access

### Frontend Web Application

After deployment, access the frontend:

```bash
# Get LoadBalancer IP
kubectl get svc otel-demo-frontend -n opentelemetry

# Access via browser
# http://<EXTERNAL-IP>
```

### Port Forwarding (Local Access)

```bash
# Forward frontend to localhost
kubectl port-forward -n opentelemetry svc/otel-demo-frontend 8080:8080

# Access at http://localhost:8080
```

### Cloud Console

- **Cloud Trace**: https://console.cloud.google.com/traces/list?project=PROJECT_ID
- **Cloud Monitoring**: https://console.cloud.google.com/monitoring?project=PROJECT_ID
- **Cloud Logging**: https://console.cloud.google.com/logs?project=PROJECT_ID

## Verification

### Check Deployment Status

```bash
# View pods
kubectl get pods -n opentelemetry

# View services
kubectl get svc -n opentelemetry

# Check collector logs
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector --tail=50
```

### Verify Traces in Cloud Trace

1. Navigate to Cloud Trace in GCP Console
2. Filter by service: `frontend`, `cartservice`, etc.
3. View trace details and service map

### Verify Metrics in Cloud Monitoring

1. Navigate to Cloud Monitoring
2. Metrics Explorer > Search: `custom.googleapis.com/opencensus`
3. View metrics from OpenTelemetry Collector

## Traffic Generation

Generate realistic traffic to create demo data:

```bash
# Using observ-demo CLI
observ-demo generate-traffic --pattern medium

# Manual load testing with hey
kubectl run -n opentelemetry load-generator \
  --image=williamyeh/hey:latest \
  --restart=Never \
  --rm -it -- \
  -z 10m -c 5 -q 1 \
  http://otel-demo-frontend:8080/
```

## Monitoring

### Key Metrics to Monitor

- **Request Rate**: Requests per second per service
- **Latency**: P50, P95, P99 latencies
- **Error Rate**: Errors per second
- **Resource Usage**: CPU and memory utilization

### Alerts

The monitoring module creates alerts for:
- Pod crash loops
- High error rates (>5/second)
- High CPU/memory usage (>80%/85%)
- Service degradation

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n opentelemetry

# Check events
kubectl get events -n opentelemetry --sort-by='.lastTimestamp'

# Common issues:
# - Image pull errors: Check GCR access
# - Resource limits: Adjust in values-gcp.yaml
# - Workload Identity: Verify service account binding
```

### Collector Not Exporting to GCP

```bash
# Check collector logs
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector

# Verify Workload Identity
kubectl get sa otel-collector-sa -n opentelemetry -o yaml

# Common issues:
# - Annotation missing: Check serviceAccount.annotations
# - IAM binding: Verify gcloud iam service-accounts add-iam-policy-binding
# - Project ID: Ensure correct PROJECT_ID in values-gcp.yaml
```

### No Traces Appearing

```bash
# Check if traces are being generated
kubectl logs -n opentelemetry <frontend-pod> | grep -i trace

# Check collector pipeline
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector | grep -i trace

# Verify sampling rate (may be too low)
# Edit values-gcp.yaml and increase probabilistic_sampler.sampling_percentage
```

### High Costs

```bash
# Reduce replica counts
kubectl scale deployment --all --replicas=1 -n opentelemetry

# Increase sampling rate (reduce traces)
# Edit values-gcp.yaml: sampling_percentage: 1.0

# Scale to zero when not in use
kubectl scale deployment --all --replicas=0 -n opentelemetry
```

## Cost Optimization

### Scale Down When Not in Use

```bash
# Scale all deployments to zero
kubectl scale deployment --all --replicas=0 -n opentelemetry

# Scale back up
kubectl scale deployment --all --replicas=1 -n opentelemetry
```

### Adjust Resource Limits

Edit `values-gcp.yaml` to reduce resource requests/limits if running continuously.

### Reduce Trace Volume

Lower sampling percentage to 1% for minimal Cloud Trace costs:

```yaml
processors:
  probabilistic_sampler:
    sampling_percentage: 1.0
```

## Cleanup

### Remove Deployment

```bash
# Using Helm
helm uninstall otel-demo -n opentelemetry

# Delete namespace
kubectl delete namespace opentelemetry
```

### Full Cleanup (Infrastructure)

```bash
# Use teardown command
observ-demo teardown
```

## Next Steps

1. **Generate Traffic**: Create realistic demo data
   ```bash
   observ-demo generate-traffic --pattern medium
   ```

2. **Explore Traces**: View distributed traces in Cloud Trace

3. **Create Dashboards**: Build custom dashboards in Cloud Monitoring

4. **Set Up Alerts**: Configure alerts for production scenarios

## References

- [OpenTelemetry Demo Documentation](https://opentelemetry.io/docs/demo/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [GCP Cloud Trace](https://cloud.google.com/trace/docs)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)

## Support

For issues or questions:
- Check the troubleshooting section above
- Review logs: `kubectl logs -n opentelemetry <pod-name>`
- Open an issue in the repository

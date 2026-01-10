## Google Microservices Demo (Online Boutique) - GKE Deployment

This directory contains Kubernetes manifests for deploying the [Google Microservices Demo](https://github.com/GoogleCloudPlatform/microservices-demo) (also known as "Online Boutique") to Google Kubernetes Engine (GKE) with OpenTelemetry integration.

## Overview

Online Boutique is a cloud-native microservices demo application consisting of 11 microservices that showcase a realistic e-commerce platform. This deployment is optimized for GKE with:

- **OpenTelemetry Integration**: Automatic instrumentation and tracing
- **GCP-Native Observability**: Cloud Trace, Monitoring, Logging
- **Workload Identity**: Secure service account management
- **Cost Optimization**: Resource limits and autoscaling
- **Production Best Practices**: Network policies, security contexts

## Architecture

```
                         ┌─────────────────┐
                         │   Load Balancer │
                         └────────┬────────┘
                                  │
                         ┌────────▼────────┐
                         │    Frontend     │
                         │   (Next.js)     │
                         └────┬─────┬──────┘
                              │     │
                 ┌────────────┼─────┼──────────────┐
                 │            │     │              │
          ┌──────▼───┐  ┌────▼──┐ ┌▼─────┐  ┌────▼────────┐
          │   Cart   │  │Product│ │  Ad  │  │Recommendation│
          │ Service  │  │Catalog│ │Service│ │   Service    │
          └────┬─────┘  └───────┘ └──────┘  └──────────────┘
               │
          ┌────▼────┐
          │  Redis  │
          └─────────┘

          ┌──────────┐  ┌─────────┐  ┌──────────┐
          │ Checkout │  │ Payment │  │ Shipping │
          │ Service  │  │ Service │  │ Service  │
          └────┬─────┘  └─────────┘  └──────────┘
               │
          ┌────▼────┐  ┌──────────┐
          │ Currency│  │  Email   │
          │ Service │  │ Service  │
          └─────────┘  └──────────┘

                  │
            ┌─────▼──────┐
            │OpenTelemetry│
            │ Collector   │
            └─────┬───────┘
                  │
       ┌──────────┼──────────┐
       │          │          │
  ┌────▼───┐ ┌───▼───┐ ┌───▼────┐
  │ Cloud  │ │ Cloud │ │ Cloud  │
  │ Trace  │ │Monitor│ │Logging │
  └────────┘ └───────┘ └────────┘
```

## Services

### Microservices

1. **Frontend** - User-facing web application (Go)
2. **Cart Service** - Shopping cart management (C#)
3. **Product Catalog Service** - Product inventory (Go)
4. **Currency Service** - Currency conversion (Node.js)
5. **Payment Service** - Payment processing (Node.js)
6. **Shipping Service** - Shipping calculations (Go)
7. **Email Service** - Email notifications (Python)
8. **Checkout Service** - Order processing (Go)
9. **Recommendation Service** - ML-based recommendations (Python)
10. **Ad Service** - Advertisement serving (Java)

### Dependencies

11. **Redis** - Cart data storage

## Prerequisites

- GKE cluster running with Workload Identity enabled
- kubectl configured to access the cluster
- (Optional) OpenTelemetry Collector deployed for traces
- GCP service account with permissions:
  - `roles/cloudtrace.agent`
  - `roles/monitoring.metricWriter`
  - `roles/logging.logWriter`

## Quick Start

### Option 1: Using Deployment Script

```bash
# Set project ID
export GCP_PROJECT_ID=your-project-id

# Make script executable
chmod +x deploy.sh

# Deploy
./deploy.sh
```

### Option 2: Manual Deployment with kubectl

```bash
# Create namespace
kubectl create namespace microservices-demo

# Deploy using official manifests
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/release/kubernetes-manifests.yaml \
  -n microservices-demo

# Wait for pods
kubectl wait --for=condition=ready pod --all -n microservices-demo --timeout=600s
```

### Option 3: Deploy with observ-demo CLI

```bash
# Deploy infrastructure and applications
observ-demo deploy --microservices

# Or deploy only microservices (infrastructure already deployed)
observ-demo deploy --no-otel --microservices
```

## Configuration

### Resource Limits (Cost Optimized)

Default resource limits for cost efficiency:

| Service | CPU Request | Memory Request | CPU Limit | Memory Limit |
|---------|-------------|----------------|-----------|--------------|
| Frontend | 100m | 128Mi | 200m | 256Mi |
| Cart Service | 100m | 128Mi | 200m | 256Mi |
| Product Catalog | 100m | 128Mi | 200m | 256Mi |
| Smaller Services | 50m | 64Mi | 100m | 128Mi |
| Redis | 50m | 64Mi | 100m | 128Mi |

**Total estimated cost**: ~$10-15/month for baseline deployment

### OpenTelemetry Integration

The deployment script automatically configures OpenTelemetry exporters if the OpenTelemetry Collector is available:

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://opentelemetry-collector.opentelemetry.svc.cluster.local:4317"
  - name: OTEL_SERVICE_NAME
    value: "frontend"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "service.version=1.0.0,deployment.environment=demo"
```

### Load Generator

The built-in load generator is **disabled by default**. Use the observ-demo traffic generation script instead:

```bash
observ-demo generate-traffic --pattern medium
```

To enable the built-in load generator:

```bash
kubectl scale deployment loadgenerator --replicas=1 -n microservices-demo
```

## Access

### Frontend Web Application

After deployment, access the frontend:

```bash
# Get LoadBalancer IP
kubectl get svc frontend-external -n microservices-demo

# Access via browser
# http://<EXTERNAL-IP>
```

### Port Forwarding (Local Access)

```bash
# Forward frontend to localhost
kubectl port-forward -n microservices-demo svc/frontend 8080:80

# Access at http://localhost:8080
```

### Cloud Console

- **Cloud Trace**: https://console.cloud.google.com/traces/list?project=PROJECT_ID
- **Cloud Monitoring**: https://console.cloud.google.com/monitoring?project=PROJECT_ID
- **Cloud Logging**: https://console.cloud.google.com/logs?project=PROJECT_ID

## Features

### Shopping Experience

The demo application provides a complete e-commerce experience:

1. **Browse Products**: View a catalog of products
2. **Search**: Search for specific products
3. **Add to Cart**: Add items to shopping cart
4. **Checkout**: Complete purchase with shipping and payment
5. **Recommendations**: ML-based product recommendations
6. **Advertisements**: Dynamic ad serving

### Observability

Each service is instrumented with OpenTelemetry:

- **Traces**: Distributed tracing across all microservices
- **Metrics**: Service-level metrics (request rate, latency, errors)
- **Logs**: Structured logging with correlation IDs
- **Service Map**: Automatic service dependency visualization

## Verification

### Check Deployment Status

```bash
# View all pods
kubectl get pods -n microservices-demo

# View services
kubectl get svc -n microservices-demo

# Check specific service logs
kubectl logs -n microservices-demo -l app=frontend --tail=50
```

### Verify Traces in Cloud Trace

1. Navigate to Cloud Trace in GCP Console
2. Filter by service: `frontend`, `cartservice`, `checkoutservice`, etc.
3. View complete request flows across microservices
4. Examine service dependencies in the trace map

### Test the Application

```bash
# Get frontend URL
FRONTEND_URL=$(kubectl get svc frontend-external -n microservices-demo \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Browse the site
echo "Visit: http://$FRONTEND_URL"

# Or port-forward
kubectl port-forward -n microservices-demo svc/frontend 8080:80
# Visit: http://localhost:8080
```

## Traffic Generation

### Using observ-demo CLI (Recommended)

```bash
# Low traffic (5 users, 1 hour)
observ-demo generate-traffic --pattern low

# Medium traffic (20 users, 30 min)
observ-demo generate-traffic --pattern medium

# High traffic (50 users, 10 min)
observ-demo generate-traffic --pattern high

# Spike test (100 users, 5 min)
observ-demo generate-traffic --pattern spike
```

### Using Built-in Load Generator

```bash
# Enable load generator
kubectl scale deployment loadgenerator --replicas=1 -n microservices-demo

# Configure load (edit deployment)
kubectl set env deployment/loadgenerator -n microservices-demo \
  USERS=10 \
  --overwrite

# Disable load generator
kubectl scale deployment loadgenerator --replicas=0 -n microservices-demo
```

### Manual Testing with curl

```bash
# Get frontend IP
FRONTEND_IP=$(kubectl get svc frontend-external -n microservices-demo \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Send requests
for i in {1..100}; do
  curl -s http://$FRONTEND_IP/ > /dev/null
  echo "Request $i sent"
  sleep 1
done
```

## Monitoring

### Key Metrics to Monitor

- **Request Rate**: Requests per second per service
- **Latency**: P50, P95, P99 response times
- **Error Rate**: HTTP 4xx/5xx errors
- **Cart Operations**: Add to cart, checkout success rate
- **Payment Success**: Payment processing success rate

### Pre-configured Alerts

The monitoring module creates alerts for:
- Pod crash loops
- High error rates (>5/second)
- High CPU usage (>80%)
- High memory usage (>85%)
- Service unavailability

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n microservices-demo

# Check events
kubectl get events -n microservices-demo --sort-by='.lastTimestamp'

# Common issues:
# - Image pull errors: Check GCR access
# - Resource limits: Adjust requests/limits
# - Workload Identity: Verify service account binding
```

### Frontend Not Accessible

```bash
# Check frontend service
kubectl get svc frontend-external -n microservices-demo

# Check frontend pods
kubectl get pods -n microservices-demo -l app=frontend

# Check frontend logs
kubectl logs -n microservices-demo -l app=frontend --tail=100

# Common issues:
# - LoadBalancer pending: Wait 2-3 minutes for IP assignment
# - Connection refused: Check pod health
# - 500 errors: Check backend service connectivity
```

### No Traces in Cloud Trace

```bash
# Check if OpenTelemetry Collector is running
kubectl get pods -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector

# Check OTEL environment variables
kubectl describe deployment frontend -n microservices-demo | grep OTEL

# Check frontend logs for OTEL errors
kubectl logs -n microservices-demo -l app=frontend | grep -i otel

# Common issues:
# - Collector not deployed: Deploy OpenTelemetry first
# - Wrong endpoint: Verify OTEL_EXPORTER_OTLP_ENDPOINT
# - Network policy: Ensure cross-namespace communication allowed
```

### High Cart Service Errors

```bash
# Check Redis
kubectl get pods -n microservices-demo -l app=redis-cart

# Check Redis logs
kubectl logs -n microservices-demo -l app=redis-cart --tail=100

# Test Redis connectivity
kubectl exec -it -n microservices-demo deployment/cartservice -- \
  sh -c 'apt-get update && apt-get install -y redis-tools && redis-cli -h redis-cart ping'

# Common issues:
# - Redis not ready: Wait for Redis pod to be ready
# - Connection timeout: Check network policies
# - Out of memory: Increase Redis memory limits
```

## Cost Optimization

### Scale Down When Not in Use

```bash
# Scale all deployments to zero
kubectl scale deployment --all --replicas=0 -n microservices-demo

# Scale back up
kubectl scale deployment --all --replicas=1 -n microservices-demo

# Keep only frontend and essential services
kubectl scale deployment --replicas=0 -n microservices-demo \
  adservice recommendationservice loadgenerator
```

### Reduce Resource Limits

For long-running demos, reduce resource requests:

```bash
# Example: Reduce frontend resources
kubectl set resources deployment frontend -n microservices-demo \
  --requests=cpu=50m,memory=64Mi \
  --limits=cpu=100m,memory=128Mi
```

### Disable Load Generator

```bash
kubectl scale deployment loadgenerator --replicas=0 -n microservices-demo
```

## Cleanup

### Remove Deployment

```bash
# Delete namespace (removes all resources)
kubectl delete namespace microservices-demo
```

### Full Cleanup (Infrastructure)

```bash
# Use teardown command
observ-demo teardown
```

## Integration with OpenTelemetry Demo

The Microservices Demo integrates seamlessly with the OpenTelemetry Demo:

1. **Shared Collector**: Both demos use the same OpenTelemetry Collector
2. **Unified Traces**: All traces appear in Cloud Trace together
3. **Service Map**: Complete dependency graph across both applications

**Deployment Order**:
```bash
# 1. Deploy OpenTelemetry Demo first
cd ../opentelemetry
./deploy.sh

# 2. Deploy Microservices Demo
cd ../microservices-demo
./deploy.sh
```

## Next Steps

1. **Explore the Application**: Browse products, add to cart, checkout
2. **Generate Traffic**: Create realistic demo data
   ```bash
   observ-demo generate-traffic --pattern medium
   ```
3. **View Traces**: Examine distributed traces in Cloud Trace
4. **Create Dashboards**: Build custom dashboards in Cloud Monitoring
5. **Set Up Alerts**: Configure production-ready alert policies

## References

- [Google Microservices Demo GitHub](https://github.com/GoogleCloudPlatform/microservices-demo)
- [Official Documentation](https://github.com/GoogleCloudPlatform/microservices-demo/blob/main/docs/README.md)
- [OpenTelemetry](https://opentelemetry.io/)
- [GCP Cloud Trace](https://cloud.google.com/trace/docs)

## Support

For issues or questions:
- Check the troubleshooting section above
- Review logs: `kubectl logs -n microservices-demo <pod-name>`
- Check official documentation
- Open an issue in the repository

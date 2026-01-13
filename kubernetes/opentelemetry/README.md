# OpenTelemetry Collector - GKE Deployment

This directory contains Helm values for deploying the [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) to Google Kubernetes Engine (GKE) as a centralized telemetry pipeline.

## Overview

The OpenTelemetry Collector receives, processes, and exports telemetry data (traces, metrics, logs) from the microservices demo application. This deployment is optimized for GKE Autopilot with:

- **Open-Source Exporters**: Jaeger (traces) and Prometheus (metrics)
- **OTLP Receiver**: Standard OpenTelemetry Protocol endpoint
- **GKE Autopilot Compatible**: Meets minimum resource requirements
- **Simplified Configuration**: Minimal processing pipeline for reliability

## Architecture

```
┌──────────────────────────────────────────────────┐
│         Microservices Demo Applications          │
│  (frontend, cartservice, checkout, etc.)        │
└──────────────────┬───────────────────────────────┘
                   │ OTLP (port 4317)
                   │
┌──────────────────▼───────────────────────────────┐
│         OpenTelemetry Collector                   │
│                                                   │
│  Receivers:                                      │
│    - otlp (gRPC: 4317, HTTP: 4318)              │
│                                                   │
│  Processors:                                     │
│    - batch (aggregates before export)            │
│                                                   │
│  Exporters:                                      │
│    - otlp/jaeger → Jaeger (traces)              │
│    - prometheus → Prometheus (metrics)           │
│    - debug → logs (troubleshooting)              │
└──────────────────┬───────────────────────────────┘
                   │
         ┌─────────┴─────────┐
         │                   │
    ┌────▼────┐        ┌─────▼──────┐
    │  Jaeger │        │ Prometheus │
    │ (traces)│        │ (metrics)  │
    └─────────┘        └────────────┘
```

## Deployment

### Using GitHub Actions (Recommended)

The OpenTelemetry Collector is automatically deployed as part of the full stack deployment:

1. Go to **Actions** → **Deploy Observability Demo**
2. Run workflow with action: `deploy`

### Manual Deployment with Helm

```bash
# Add OpenTelemetry Helm repository
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Create namespace
kubectl create namespace opentelemetry

# Deploy collector
helm upgrade --install otel-collector \
  open-telemetry/opentelemetry-collector \
  --namespace opentelemetry \
  --values values-collector.yaml \
  --timeout 10m

# Verify deployment
kubectl get pods -n opentelemetry
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector
```

## Configuration

### Key Settings in values-collector.yaml

```yaml
# Image configuration
image:
  repository: otel/opentelemetry-collector-contrib
  tag: 0.112.0

# GKE Autopilot minimum resources
resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: 500m
    memory: 1Gi

# Collector configuration
config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

  processors:
    batch:
      timeout: 10s
      send_batch_size: 1024

  exporters:
    otlp/jaeger:
      endpoint: jaeger-collector.observability.svc.cluster.local:4317
      tls:
        insecure: true

    prometheus:
      endpoint: 0.0.0.0:8889
      namespace: otel

    debug:
      verbosity: basic

  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [batch]
        exporters: [otlp/jaeger, debug]

      metrics:
        receivers: [otlp]
        processors: [batch]
        exporters: [prometheus, debug]
```

## Resource Requirements

**GKE Autopilot Minimums:**
- CPU Request: 250m (minimum enforced by Autopilot)
- Memory Request: 512Mi (minimum enforced by Autopilot)
- CPU Limit: 500m
- Memory Limit: 1Gi

**Cost:** ~$8-10/month for 24/7 operation

## Service Endpoints

The collector exposes the following endpoints:

| Endpoint | Port | Protocol | Purpose |
|----------|------|----------|---------|
| OTLP gRPC | 4317 | gRPC | Receive traces/metrics from apps |
| OTLP HTTP | 4318 | HTTP | Alternative HTTP endpoint |
| Prometheus | 8889 | HTTP | Scrape metrics |
| Health Check | 13133 | HTTP | Liveness/readiness probes |

### Accessing from Microservices

Applications can send telemetry to:

```bash
# Service DNS name (from within cluster)
otel-collector-opentelemetry-collector.opentelemetry.svc.cluster.local:4317

# Environment variable configuration
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector-opentelemetry-collector.opentelemetry.svc.cluster.local:4317
```

## Verification

### Check Collector Status

```bash
# Check pods
kubectl get pods -n opentelemetry

# View logs
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector

# Check service
kubectl get svc -n opentelemetry
```

### Test OTLP Endpoint

```bash
# Port-forward to test locally
kubectl port-forward -n opentelemetry svc/otel-collector-opentelemetry-collector 4317:4317

# Send test trace (requires opentelemetry-collector-contrib installed)
# Or check if microservices are connecting by viewing collector logs
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector --tail=50
```

### Verify Data Export

```bash
# Check Jaeger for traces
kubectl port-forward -n observability svc/jaeger-query 16686:16686
# Visit http://localhost:16686

# Check Prometheus for metrics
kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets (look for "otel" targets)
```

## Troubleshooting

### Collector Pod Not Starting

```bash
# Check pod status
kubectl describe pod -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector

# Common issues:
# 1. Resource requirements below GKE Autopilot minimums
#    Solution: Ensure at least 250m CPU, 512Mi memory
# 2. Image pull errors
#    Solution: Check image repository and tag
# 3. ConfigMap errors
#    Solution: Validate YAML syntax in values-collector.yaml
```

### No Traces in Jaeger

```bash
# 1. Check collector logs for errors
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector | grep -i error

# 2. Verify Jaeger connectivity
kubectl exec -n opentelemetry -it deployment/otel-collector-opentelemetry-collector -- \
  sh -c "nc -zv jaeger-collector.observability.svc.cluster.local 4317"

# 3. Check if microservices are sending data
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector | grep -i "traces"
```

### High Memory Usage

```bash
# Check resource usage
kubectl top pod -n opentelemetry

# If memory is near limit, increase in values-collector.yaml:
resources:
  requests:
    memory: 1Gi  # increased from 512Mi
  limits:
    memory: 2Gi  # increased from 1Gi
```

### Connection Refused from Microservices

```bash
# 1. Verify service exists
kubectl get svc -n opentelemetry

# 2. Check network policies allow traffic
kubectl get networkpolicies -A

# 3. Test connectivity from microservices namespace
kubectl run -it --rm test --image=busybox --restart=Never -n microservices-demo -- \
  sh -c "nc -zv otel-collector-opentelemetry-collector.opentelemetry.svc.cluster.local 4317"
```

## Configuration Updates

### Update Collector Configuration

1. Edit [values-collector.yaml](values-collector.yaml)
2. Apply changes:
   ```bash
   helm upgrade otel-collector \
     open-telemetry/opentelemetry-collector \
     --namespace opentelemetry \
     --values values-collector.yaml
   ```
3. Verify:
   ```bash
   kubectl rollout status deployment -n opentelemetry
   kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector --tail=50
   ```

### Enable Additional Exporters

The collector supports many exporters. To add Cloud Trace export:

```yaml
exporters:
  googlecloud:
    project: your-project-id
    # Requires Workload Identity configured

service:
  pipelines:
    traces:
      exporters: [otlp/jaeger, googlecloud, debug]
```

### Enable Sampling

To reduce trace volume:

```yaml
processors:
  probabilistic_sampler:
    sampling_percentage: 10  # Sample 10% of traces

service:
  pipelines:
    traces:
      processors: [probabilistic_sampler, batch]
```

## Performance Tuning

### Batch Processor

Adjust batching for throughput:

```yaml
processors:
  batch:
    timeout: 5s          # Reduce for lower latency
    send_batch_size: 512 # Reduce for lower memory
    send_batch_max_size: 1024
```

### Resource Scaling

For high-volume environments:

```yaml
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi

# Enable horizontal scaling
replicaCount: 2
```

## Cost Optimization

### Monthly Cost Breakdown (24/7)

| Configuration | CPU | Memory | Cost |
|---------------|-----|--------|------|
| **Minimal (current)** | 250m | 512Mi | $8-10 |
| Medium | 500m | 1Gi | $15-20 |
| High | 1000m | 2Gi | $30-40 |

### Optimization Tips

1. **Scale to zero when not in use:**
   ```bash
   kubectl scale deployment -n opentelemetry --replicas=0 --all
   ```

2. **Enable sampling** - Reduce trace volume by 90%
3. **Adjust batch size** - Larger batches = fewer exports
4. **Remove debug exporter** - Reduces log volume

## Integration

### Microservices Demo Integration

The Google Microservices Demo automatically connects to this collector:

```yaml
# In microservices-demo values-gcp.yaml
opentelemetryCollector:
  create: false  # We use this dedicated collector instead
```

### Custom Application Integration

Configure your application to send to the collector:

```bash
# Environment variables
export OTEL_EXPORTER_OTLP_ENDPOINT="http://otel-collector-opentelemetry-collector.opentelemetry.svc.cluster.local:4317"
export OTEL_SERVICE_NAME="my-service"
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=demo"
```

## References

- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)
- [Helm Chart Repository](https://github.com/open-telemetry/opentelemetry-helm-charts)
- [Collector Configuration Reference](https://opentelemetry.io/docs/collector/configuration/)
- [Available Exporters](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter)

## Support

For issues:
1. Check collector logs: `kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector`
2. Review configuration: `kubectl get configmap -n opentelemetry -o yaml`
3. Verify network connectivity between namespaces
4. Check [main README](../../README.md) for general troubleshooting

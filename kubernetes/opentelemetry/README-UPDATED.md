# OpenTelemetry Collector - Open Source Observability

This directory deploys **ONLY the OpenTelemetry Collector** (the telemetry platform), NOT the OpenTelemetry Demo application.

## Purpose

The OpenTelemetry Collector receives telemetry data (traces, metrics, logs) from the **Google Microservices Demo** application and exports it to open-source observability backends:

```
Google Microservices Demo (11 microservices)
         ↓
    (sends telemetry via OTLP)
         ↓
OpenTelemetry Collector
    ↓       ↓       ↓
Jaeger  Prometheus  Logging
  ↓         ↓
        Grafana
```

## What is OpenTelemetry Collector?

The OpenTelemetry Collector is a vendor-agnostic telemetry data pipeline that:
- **Receives** telemetry data in multiple formats (OTLP, Jaeger, Zipkin, Prometheus, etc.)
- **Processes** telemetry data (batching, sampling, filtering, transforming)
- **Exports** telemetry data to various backends (GCP, AWS, Datadog, etc.)

Think of it as a "telemetry router" that sits between your applications and your observability backend.

## Architecture

### Components Deployed

This deployment creates:
- **OpenTelemetry Collector** (2 replicas for HA)
- **Kubernetes Service** (ClusterIP)
- **ServiceAccount** with Workload Identity for GCP authentication
- **Network Policies** for secure communication
- **HorizontalPodAutoscaler** (2-5 replicas based on load)

### What is NOT Deployed

- ❌ OpenTelemetry Demo application (we don't need this)
- ❌ Any frontend/UI components
- ❌ Load balancers or ingresses

The collector is an internal service only - applications send telemetry to it, and it forwards to GCP.

## Configuration

### Receivers

The collector accepts telemetry via:
- **OTLP gRPC** on port 4317 (default for OpenTelemetry SDKs)
- **OTLP HTTP** on port 4318 (HTTP-based alternative)
- **Prometheus** on port 8888 (self-monitoring)

### Processors

Telemetry data is processed through:
- **Memory Limiter**: Prevents OOM by limiting memory usage
- **Resource Detection**: Adds GCP metadata (project, cluster, zone)
- **Attributes**: Adds custom tags (environment: demo)
- **Probabilistic Sampler**: Samples 10% of traces to reduce costs
- **Batch**: Batches data for efficient export

### Exporters

Telemetry is exported to:
- **Jaeger**: Distributed tracing backend with UI
- **Prometheus**: Metrics in Prometheus format for scraping
- **Logging**: Debug output (can be disabled)

**Note:** The backends (Jaeger, Prometheus, Grafana) are deployed separately in the `observability` namespace.

## Prerequisites

- GKE cluster with kubectl configured
- Observability stack deployed (Jaeger, Prometheus, Grafana)
  - See `kubernetes/observability/` directory
- Helm 3.x installed
- kubectl configured

## Deployment

### Option 1: Automated Script

```bash
# Set your project ID
export GCP_PROJECT_ID=your-project-id

# Make script executable
chmod +x deploy.sh

# Deploy
./deploy.sh
```

### Option 2: Manual Helm Deployment

```bash
# Add Helm repository
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Create namespace
kubectl create namespace opentelemetry
kubectl label namespace opentelemetry name=opentelemetry

# Deploy collector
helm upgrade --install otel-collector \
  open-telemetry/opentelemetry-collector \
  --namespace opentelemetry \
  --values values-collector.yaml \
  --wait
```

### Option 3: Using observ-demo CLI

```bash
# Deploy only the collector (not the demo app)
observ-demo deploy --otel --no-microservices
```

## Verification

### Check Collector Status

```bash
# View collector pods
kubectl get pods -n opentelemetry

# Should show 2 collector pods running:
# NAME                                  READY   STATUS    RESTARTS   AGE
# otel-collector-xxxxx                  1/1     Running   0          2m
# otel-collector-yyyyy                  1/1     Running   0          2m
```

### Check Collector Logs

```bash
# View collector logs
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector --tail=50

# You should see:
# - "Everything is ready. Begin running and processing data."
# - Successful connection to GCP APIs
# - NO application traces yet (will appear after deploying Microservices Demo)
```

### Test Collector Health

```bash
# Port-forward health check endpoint
kubectl port-forward -n opentelemetry svc/otel-collector 13133:13133

# Check health (in another terminal)
curl http://localhost:13133

# Should return status indicating collector is healthy
```

### Verify Observability Integration

```bash
# Check if observability namespace exists
kubectl get namespace observability

# Verify Jaeger service is accessible
kubectl get svc -n observability jaeger-collector

# Test connectivity to Jaeger
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://jaeger-collector.observability.svc.cluster.local:14250
```

## Integration with Microservices Demo

After deploying the collector, configure the Microservices Demo to send telemetry:

### Environment Variables for Microservices

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector.opentelemetry.svc.cluster.local:4317"
  - name: OTEL_SERVICE_NAME
    value: "frontend"  # or cartservice, checkoutservice, etc.
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "deployment.environment=demo,service.version=1.0.0"
```

### Collector Endpoint

Applications should send telemetry to:
- **Internal DNS**: `otel-collector.opentelemetry.svc.cluster.local:4317`
- **Port**: 4317 (gRPC) or 4318 (HTTP)

This is already configured in the Microservices Demo deployment!

## Monitoring the Collector

### Collector Metrics

The collector exposes its own metrics on port 8888:

```bash
# Port-forward metrics endpoint
kubectl port-forward -n opentelemetry svc/otel-collector 8888:8888

# View metrics
curl http://localhost:8888/metrics
```

**Key metrics to monitor:**
- `otelcol_receiver_accepted_spans`: Spans received
- `otelcol_exporter_sent_spans`: Spans exported to GCP
- `otelcol_processor_dropped_spans`: Dropped spans (should be low)
- `otelcol_exporter_send_failed_spans`: Export failures (should be zero)

### Jaeger Traces

After deploying Microservices Demo and generating traffic:

```bash
# Port-forward to Jaeger UI
kubectl port-forward -n observability svc/jaeger-query 16686:16686

# Access Jaeger UI
http://localhost:16686

# You should see traces from:
# - frontend
# - cartservice
# - productcatalogservice
# - checkoutservice
# - etc.
```

## Configuration

### Sampling Rate

By default, 100% of traces are sampled for demo/learning purposes:

```yaml
processors:
  probabilistic_sampler:
    sampling_percentage: 100.0
```

**To adjust for production:**
- 10% sampling: Change to `sampling_percentage: 10.0`
- 1% sampling: Change to `sampling_percentage: 1.0`

Then redeploy:
```bash
helm upgrade otel-collector open-telemetry/opentelemetry-collector \
  -n opentelemetry --values values-collector.yaml
```

### Resource Limits

Default resource configuration:

```yaml
resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: 500m
    memory: 1Gi
```

**Estimated cost**: ~$5-10/month for the collector

**Note:** The observability backends (Jaeger, Prometheus, Grafana) cost an additional ~$33-50/month.

## Troubleshooting

### No Traces Appearing in Cloud Trace

**Check collector logs:**
```bash
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector | grep -i error
```

**Common issues:**
1. **Observability stack not deployed**: Deploy Jaeger/Prometheus first
2. **Network connectivity**: Check if Jaeger service is accessible
3. **No telemetry being sent**: Microservices Demo not deployed yet
4. **Sampling too low**: Increase sampling percentage (currently 100%)
5. **Network policy blocking**: Check namespace labels

### Collector Pods Not Starting

```bash
# Describe pod
kubectl describe pod -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector

# Common issues:
# - Image pull errors: Check internet connectivity
# - Resource limits: Increase memory/CPU
# - Configuration errors: Check values-collector.yaml syntax
```

### Collector Crashing (OOMKilled)

```bash
# Check pod status
kubectl get pods -n opentelemetry

# If you see OOMKilled:
# 1. Increase memory limits in values-collector.yaml
# 2. Reduce batch size or sampling rate
# 3. Check for memory leaks in logs
```

### Export Failures

```bash
# Check collector logs for export errors
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector | grep -i "export\|error\|jaeger"

# Common issues:
# - Jaeger service not deployed or not ready
# - Network connectivity to observability namespace blocked
# - Incorrect Jaeger endpoint in configuration
# - Network policy restricting egress
```

## Cost Optimization

### Collector Costs

The collector itself is lightweight:
- **2 pods**: ~$5-10/month
- **With autoscaling to 5 pods**: ~$15-20/month

### Reduce Resource Usage

1. **Reduce sampling rate** from 100% to 10%:
   - Change `sampling_percentage: 100.0` to `10.0`
   - Reduces trace volume by 90%
   - Still captures significant traces for debugging

2. **Filter unnecessary telemetry**:
   ```yaml
   processors:
     filter:
       traces:
         exclude:
           - attributes["http.target"] == "/healthz"
   ```

3. **Batch more aggressively**:
   ```yaml
   processors:
     batch:
       timeout: 30s
       send_batch_size: 5000
   ```

## Cleanup

### Remove Collector

```bash
# Using Helm
helm uninstall otel-collector -n opentelemetry

# Delete namespace
kubectl delete namespace opentelemetry
```

### Full Teardown

```bash
# Use teardown command
observ-demo teardown
```

## Next Steps

1. **Ensure Observability Stack is Deployed**:
   ```bash
   cd ../observability
   ./deploy-observability-stack.sh
   ```

2. **Deploy Microservices Demo**: The collector is ready to receive telemetry
   ```bash
   cd ../microservices-demo
   ./deploy.sh
   ```

3. **Generate Traffic**: Create demo data
   ```bash
   observ-demo generate-traffic --pattern medium
   ```

4. **View Traces**: Navigate to Jaeger UI and explore distributed traces
   ```bash
   kubectl port-forward -n observability svc/jaeger-query 16686:16686
   # Access: http://localhost:16686
   ```

5. **View Metrics**: Navigate to Prometheus
   ```bash
   kubectl port-forward -n observability svc/prometheus-server 9090:9090
   # Access: http://localhost:9090
   ```

6. **View Dashboards**: Navigate to Grafana
   ```bash
   kubectl port-forward -n observability svc/grafana 3000:3000
   # Access: http://localhost:3000 (admin/admin123)
   ```

## Learn More

- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)
- [OpenTelemetry Specification](https://opentelemetry.io/docs/specs/otel/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

## Support

For issues:
- Check collector logs: `kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector`
- Verify observability stack: `kubectl get pods -n observability`
- Test connectivity: `kubectl exec -it -n opentelemetry <collector-pod> -- curl http://jaeger-collector.observability.svc.cluster.local:14250`

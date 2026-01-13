# Open Source Observability Stack

This directory deploys a complete open-source observability stack for the Microservices Demo, providing industry-standard SRE tools for learning and practicing observability.

## Architecture

```
Google Microservices Demo (11 microservices)
         ↓
    (sends telemetry via OTLP)
         ↓
OpenTelemetry Collector
    ↓       ↓       ↓
Jaeger  Prometheus  (Logging)
   ↓         ↓
      Grafana
   (Unified Visualization)
```

## Components

### 1. Jaeger - Distributed Tracing

**Purpose:** Capture and visualize distributed traces across microservices

**Features:**
- Distributed transaction monitoring
- Performance optimization insights
- Root cause analysis
- Service dependency visualization
- Trace search and filtering

**Access:** Port 16686 (UI), 14250 (gRPC collector)

**Use Cases:**
- Debug latency issues
- Understand service dependencies
- Identify bottlenecks in request flow
- Track requests across microservices

### 2. Prometheus - Metrics and Alerting

**Purpose:** Time-series metrics database with powerful querying (PromQL)

**Features:**
- Multi-dimensional data model
- Flexible query language (PromQL)
- Built-in alerting (Alertmanager)
- Service discovery for Kubernetes
- Recording rules for SLIs

**Access:** Port 9090 (UI and API)

**Use Cases:**
- Monitor Golden Signals (latency, traffic, errors, saturation)
- Track SLIs and SLOs
- Define alert rules for SLO violations
- Query historical metrics

### 3. Grafana - Unified Visualization

**Purpose:** Unified dashboard platform for metrics and traces

**Features:**
- Pre-configured datasources (Prometheus, Jaeger)
- SRE-focused dashboards
- Custom dashboard creation
- Alerting integration
- Explore UI for ad-hoc analysis

**Access:** Port 3000 (UI)
**Credentials:** Username: `admin` / Password: `admin123`

**Included Dashboards:**
- **SRE Golden Signals** - Traffic, Errors, Latency, Saturation
- **SLO Tracking** - Availability, Error Rate, Latency targets
- **Error Budget** - SLO compliance and budget consumption

### 4. OpenTelemetry Collector

**Purpose:** Vendor-agnostic telemetry pipeline

**Configuration:**
- **Receivers:** OTLP (gRPC and HTTP)
- **Processors:** Kubernetes attributes, batching, sampling
- **Exporters:** Jaeger (traces), Prometheus (metrics)

**Note:** Deployed separately in the `opentelemetry` namespace

## Deployment

### Prerequisites

- GKE cluster with kubectl configured
- Helm 3.x installed
- At least 4GB of available memory in the cluster

### Option 1: Automated Deployment (Recommended)

```bash
# Make script executable
chmod +x deploy-observability-stack.sh

# Deploy entire stack
./deploy-observability-stack.sh
```

The script will deploy in order:
1. Create `observability` namespace
2. Deploy Jaeger
3. Deploy Prometheus (with Alertmanager)
4. Deploy Grafana (with dashboards)

### Option 2: Manual Deployment

#### Step 1: Create Namespace

```bash
kubectl create namespace observability
kubectl label namespace observability name=observability
```

#### Step 2: Deploy Jaeger

```bash
kubectl apply -f jaeger-all-in-one.yaml

# Wait for ready
kubectl wait --for=condition=ready pod \
  --selector=app=jaeger \
  --namespace=observability \
  --timeout=300s
```

#### Step 3: Deploy Prometheus

```bash
# Add Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Deploy
helm upgrade --install prometheus \
  prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --values prometheus-values.yaml \
  --wait
```

#### Step 4: Deploy Grafana

```bash
kubectl apply -f grafana.yaml

# Wait for ready
kubectl wait --for=condition=ready pod \
  --selector=app=grafana \
  --namespace=observability \
  --timeout=300s
```

## Accessing the Stack

### Port Forwarding (Local Access)

**Jaeger UI (Traces):**
```bash
kubectl port-forward -n observability svc/jaeger-query 16686:16686
```
Access: http://localhost:16686

**Prometheus (Metrics):**
```bash
kubectl port-forward -n observability svc/prometheus-server 9090:9090
```
Access: http://localhost:9090

**Grafana (Dashboards):**
```bash
kubectl port-forward -n observability svc/grafana 3000:3000
```
Access: http://localhost:3000
Username: `admin`
Password: `admin123`

### Ingress (Cluster Access)

Ingress resources are configured for:
- Jaeger: `/jaeger`
- Grafana: `/grafana`

Get the external IP:
```bash
kubectl get ingress -n observability
```

## Using the Stack

### 1. Viewing Distributed Traces (Jaeger)

After deploying the Microservices Demo and generating traffic:

1. Access Jaeger UI: http://localhost:16686
2. Select a service from the dropdown (e.g., `frontend`)
3. Click "Find Traces"
4. Click on a trace to view the full request flow

**What to look for:**
- Trace duration (total latency)
- Number of spans (service calls)
- Error spans (red color)
- Service dependencies

**Example Query:**
- Service: `frontend`
- Min Duration: `100ms`
- Max Duration: `5s`
- Tags: `error=true`

### 2. Querying Metrics (Prometheus)

Access Prometheus UI: http://localhost:9090

**Example PromQL Queries:**

**Request Rate (RPS):**
```promql
sum(rate(http_server_requests_total[1m])) by (service)
```

**Error Rate:**
```promql
sum(rate(http_server_requests_total{status=~"5.."}[5m])) by (service)
/
sum(rate(http_server_requests_total[5m])) by (service)
```

**P95 Latency:**
```promql
histogram_quantile(0.95,
  sum(rate(http_server_duration_bucket[5m])) by (service, le)
)
```

**CPU Usage:**
```promql
sum(rate(container_cpu_usage_seconds_total{namespace="microservices-demo"}[5m])) by (pod)
```

### 3. Visualizing with Grafana

Access Grafana: http://localhost:3000 (admin/admin123)

**Pre-configured Dashboards:**

1. **SRE Golden Signals**
   - Traffic: Request rate per service
   - Errors: Error rate gauge
   - Latency: P50, P95, P99 percentiles
   - Saturation: CPU and memory utilization

2. **SLO Tracking**
   - Availability gauge (99% target)
   - Error rate gauge (<1% target)
   - P95 latency gauge (<500ms target)
   - Error budget consumption over time
   - Request status distribution (2xx, 4xx, 5xx)

**Creating Custom Dashboards:**
1. Click "+" → "Dashboard" → "Add new panel"
2. Select "Prometheus" as datasource
3. Enter PromQL query
4. Configure visualization
5. Save dashboard

**Exploring Traces in Grafana:**
1. Click "Explore" (compass icon)
2. Select "Jaeger" datasource
3. Search for traces
4. View trace details and service map

## SRE Practices

### Golden Signals

The four key metrics to monitor:

1. **Latency** - How long requests take
2. **Traffic** - How many requests
3. **Errors** - Rate of failed requests
4. **Saturation** - Resource utilization

All four are visualized in the "SRE Golden Signals" dashboard.

### SLIs and SLOs

**Service Level Indicators (SLIs):**
- Availability: % of successful requests
- Latency: P95 response time
- Error rate: % of 5xx responses

**Service Level Objectives (SLOs):**
- Availability: 99% (1% error budget)
- Latency: P95 < 500ms
- Error Rate: < 1%

**Tracking:**
View the "SLO Tracking" dashboard to monitor:
- Current SLO compliance
- Error budget remaining
- Historical trends

### Alerting

Prometheus is configured with alert rules for SLO violations:

**View Active Alerts:**
```bash
kubectl port-forward -n observability svc/prometheus-alertmanager 9093:9093
```
Access: http://localhost:9093

**Configured Alerts:**
- HighErrorRate (> 5% for 5 minutes)
- CriticalErrorRate (> 10% for 2 minutes)
- HighLatencyP95 (> 1s for 5 minutes)
- HighLatencyP99 (> 2s for 5 minutes)
- LowAvailability (< 99% for 5 minutes)
- ServiceDown (service unavailable for 1 minute)

**Alert Configuration:**
Edit `prometheus-values.yaml` → `additionalPrometheusRulesMap`

## Troubleshooting

### No Traces in Jaeger

**Check OpenTelemetry Collector:**
```bash
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector --tail=50 | grep -i jaeger
```

**Verify Jaeger endpoint:**
```bash
kubectl get svc -n observability jaeger-collector
```

**Test connectivity:**
```bash
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://jaeger-collector.observability.svc.cluster.local:14250
```

**Common Issues:**
- Microservices Demo not deployed
- OpenTelemetry Collector not configured correctly
- Network policy blocking traffic
- Sampling rate too low (check `probabilistic_sampler`)

### No Metrics in Prometheus

**Check Prometheus targets:**
```bash
kubectl port-forward -n observability svc/prometheus-server 9090:9090
```
Navigate to: http://localhost:9090/targets

**Verify OpenTelemetry Collector metrics endpoint:**
```bash
kubectl port-forward -n opentelemetry svc/otel-collector 8889:8889
curl http://localhost:8889/metrics
```

**Check Prometheus logs:**
```bash
kubectl logs -n observability -l app.kubernetes.io/name=prometheus --tail=50
```

### Grafana Dashboards Not Loading

**Check datasource configuration:**
1. Access Grafana: http://localhost:3000
2. Configuration → Data Sources
3. Test both Prometheus and Jaeger

**Verify services are running:**
```bash
kubectl get pods -n observability
kubectl get svc -n observability
```

**Reimport dashboards:**
```bash
kubectl delete configmap grafana-dashboards-sre -n observability
kubectl create configmap grafana-dashboards-sre --from-file=dashboards/ -n observability
kubectl rollout restart deployment/grafana -n observability
```

### High Memory Usage

The observability stack is configured for GKE Autopilot minimum requirements:

**Current Resource Allocation (GKE Autopilot Minimums):**

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| Jaeger | 250m | 512Mi | 500m | 1Gi |
| Prometheus Server | 250m | 512Mi | 1000m | 2Gi |
| Prometheus Operator | 250m | 512Mi | 500m | 1Gi |
| Alertmanager | 250m | 512Mi | 500m | 1Gi |
| Kube State Metrics | 250m | 512Mi | 500m | 1Gi |
| Grafana | 250m | 512Mi | 500m | 1Gi |

**Important:** GKE Autopilot enforces minimum 250m CPU and 512Mi memory per container.

**To reduce storage usage:**

1. **Reduce Prometheus retention:**
   Edit `prometheus-values.yaml`:
   ```yaml
   retention: 3d
   retentionSize: "3GB"
   ```

2. **Reduce Jaeger trace retention:**
   Edit `jaeger-all-in-one.yaml`:
   ```yaml
   args:
     - "--memory.max-traces=5000"
   ```

## Cost Optimization

### Resource Costs (Monthly, 24/7)

| Component | Resources | Estimated Cost |
|-----------|-----------|----------------|
| Jaeger | 250m CPU, 512Mi RAM | ~$8-12 |
| Prometheus (Server + Operator + Alertmanager) | 750m CPU, 1.5Gi RAM | ~$25-35 |
| Kube State Metrics | 250m CPU, 512Mi RAM | ~$8-10 |
| Grafana | 250m CPU, 512Mi RAM | ~$8-10 |
| **Total** | ~1.5 vCPU, 3Gi RAM | **$50-70** |

**Note:** This is in addition to the OpenTelemetry Collector (~$5-10) and Microservices Demo (~$25-30).

### Optimization Strategies

1. **Use smaller retention periods:**
   - Prometheus: 3 days instead of 7 days
   - Jaeger: 5000 traces instead of 10000

2. **Reduce sampling for production:**
   - Change OpenTelemetry Collector sampling from 100% to 10%
   - Edit `values-collector.yaml` → `probabilistic_sampler: 10.0`

3. **Shutdown when not in use:**
   ```bash
   kubectl scale deployment -n observability --replicas=0 --all
   ```

4. **Start up when needed:**
   ```bash
   kubectl scale deployment -n observability --replicas=1 --all
   ```

## Cleanup

### Remove Observability Stack

```bash
# Delete namespace (removes all components)
kubectl delete namespace observability
```

### Selective Cleanup

```bash
# Remove Grafana only
kubectl delete -f grafana.yaml

# Remove Prometheus only
helm uninstall prometheus -n observability

# Remove Jaeger only
kubectl delete -f jaeger-all-in-one.yaml
```

## Next Steps

1. **Deploy OpenTelemetry Collector:**
   ```bash
   cd ../opentelemetry
   ./deploy.sh
   ```

2. **Deploy Microservices Demo:**
   ```bash
   cd ../microservices-demo
   ./deploy.sh
   ```

3. **Generate Traffic:**
   ```bash
   observ-demo generate-traffic --pattern medium
   ```

4. **Explore the Stack:**
   - View traces in Jaeger
   - Query metrics in Prometheus
   - Analyze dashboards in Grafana

5. **Learn SRE Practices:**
   - Monitor Golden Signals
   - Track SLOs and error budgets
   - Create custom alerts
   - Build custom dashboards

## Learn More

- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [SRE Book - Google](https://sre.google/books/)
- [The Four Golden Signals](https://sre.google/sre-book/monitoring-distributed-systems/)

## Support

For issues or questions:
- Check logs: `kubectl logs -n observability <pod-name>`
- Verify connectivity: `kubectl get pods,svc -n observability`
- Test endpoints: Port-forward and access via browser
- Review configurations in `prometheus-values.yaml` and `values-collector.yaml`

# GCP Observability Demo - Automated Deployment

A production-ready automation platform for deploying and managing observability demos on Google Cloud Platform (GCP) using **industry-standard open-source tools** (Jaeger, Prometheus, Grafana).

**Perfect for:** SRE teams, DevOps engineers, and anyone learning observability practices with OpenTelemetry, distributed tracing, and metrics monitoring.

## Overview

This automation platform enables you to:
- **Deploy open-source observability stack** (Jaeger, Prometheus, Grafana) on GKE
- **Configure GCP infrastructure** with security best practices (private GKE, IAP, Workload Identity)
- **Deploy OpenTelemetry Collector** as vendor-agnostic telemetry pipeline
- **Deploy Google Microservices Demo** with full OpenTelemetry instrumentation
- **Generate realistic traffic** with user behavior patterns (browse, cart, checkout)
- **Learn SRE practices** with Golden Signals, SLOs, error budgets, and alerting
- **Monitor costs** with budget alerts and auto-shutdown capabilities

## Key Features

### Security-First Design
- ✅ Zero public endpoints (all access via IAP)
- ✅ Workload Identity (no service account keys)
- ✅ Private GKE cluster
- ✅ Least privilege IAM permissions
- ✅ Encryption at rest and in transit

### Cost-Optimized
- 💰 **$60-80/month** for 24/7 operation (open-source stack)
- 💰 GKE Autopilot (pay only for running pods) - ~$25-30/mo
- 💰 Jaeger + Prometheus + Grafana - ~$33-50/mo
- 💰 On-demand shutdown/startup (scale to zero)
- 💰 Resource quotas and autoscaling (2-5 replicas)
- 💰 Budget alerts and cost monitoring

### Fully Automated
- 🚀 Single-command deployment (45-75 minutes)
- 🚀 Interactive CLI with validation
- 🚀 Comprehensive error handling
- 🚀 Automatic rollback on failures
- 🚀 Health monitoring and alerts

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GKE Autopilot Cluster                    │
│                                                             │
│  ┌──────────────────┐      ┌─────────────────────────┐    │
│  │  Microservices   │      │   Observability Stack   │    │
│  │      Demo        │      │                         │    │
│  │                  │      │  ┌──────────────────┐   │    │
│  │  • frontend      │─────▶│  │  OpenTelemetry   │   │    │
│  │  • cartservice   │ OTLP │  │    Collector     │   │    │
│  │  • checkout      │      │  └────────┬─────────┘   │    │
│  │  • currency      │      │           │             │    │
│  │  • payment       │      │     ┌─────┴─────┐       │    │
│  │  • product       │      │     ▼           ▼       │    │
│  │  • shipping      │      │  ┌────────┐ ┌─────────┐ │    │
│  │  • email         │      │  │ Jaeger │ │Prometh- │ │    │
│  │  • recommend     │      │  │        │ │  eus    │ │    │
│  │  • ads           │      │  └───┬────┘ └────┬────┘ │    │
│  │  • redis/cart    │      │      │           │      │    │
│  └──────────────────┘      │      └─────┬─────┘      │    │
│                            │            ▼            │    │
│  ┌──────────────────┐      │      ┌──────────┐      │    │
│  │     Traffic      │      │      │ Grafana  │      │    │
│  │    Generator     │      │      └──────────┘      │    │
│  └──────────────────┘      └─────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Key Components:**
- **OpenTelemetry Collector**: Receives telemetry via OTLP, exports to Jaeger/Prometheus
- **Jaeger**: Distributed tracing backend with UI for trace visualization
- **Prometheus**: Metrics database with PromQL for SLO tracking and alerting
- **Grafana**: Unified dashboards for Golden Signals, SLOs, and error budgets
- **Microservices Demo**: 11 polyglot services generating realistic telemetry

## Technology Stack

### Infrastructure
- **Cloud Provider**: GCP (AWS/Azure support planned)
- **IaC**: Terraform (modular, cloud-agnostic design)
- **Compute**: GKE Autopilot (cost-optimized, fully managed)
- **Networking**: Private VPC, Cloud NAT, IAP
- **Security**: Workload Identity, Pod Security Standards

### Observability (Open Source)
- **Tracing**: Jaeger (distributed tracing backend + UI)
- **Metrics**: Prometheus (time-series database + alerting)
- **Visualization**: Grafana (dashboards + explore UI)
- **Pipeline**: OpenTelemetry Collector (vendor-agnostic)
- **Protocol**: OTLP (OpenTelemetry Protocol)

### Automation
- **CLI**: Python (Click, Pydantic, Rich)
- **Deployment**: Helm charts for K8s applications
- **Traffic Generation**: Locust with realistic user journeys

## Prerequisites

### Required Tools
- **Python 3.11+** - [Install Python](https://www.python.org/downloads/)
- **Terraform 1.6+** - [Install Terraform](https://developer.hashicorp.com/terraform/install)
- **gcloud CLI** - [Install gcloud](https://cloud.google.com/sdk/docs/install)
- **kubectl** - [Install kubectl](https://kubernetes.io/docs/tasks/tools/)

### GCP Requirements
- GCP account with billing enabled
- Project owner or editor permissions
- Billing account access
- Organization admin (optional, for org policies)

### Required GCP APIs
These will be enabled automatically:
- Compute Engine API
- Kubernetes Engine API
- Cloud Resource Manager API
- IAM API
- Cloud Logging API
- Cloud Monitoring API
- Cloud Trace API
- Service Networking API

## Quick Start

### 1. Clone and Install

```bash
# Clone the repository
cd observ-demo

# Install the CLI
cd cli
pip install -e .

# Verify installation
observ-demo --help
```

### 2. Authenticate with GCP

```bash
# Login to GCP
gcloud auth login

# Set application default credentials
gcloud auth application-default login
```

### 3. Initialize GCP Project

```bash
# Interactive initialization
observ-demo init

# You'll be prompted for:
# - GCP Project ID
# - Billing Account ID
# - Default Region (e.g., us-central1)
# - Organization ID (optional)
```

### 4. Configure Deployment

```bash
# Interactive configuration wizard
observ-demo configure

# Or create config file manually
cp config/config.example.yaml .config.yaml
# Edit .config.yaml with your preferences
```

### 5. Validate Prerequisites

```bash
# Check all prerequisites
observ-demo validate
```

### 6. Deploy

```bash
# Deploy complete stack
observ-demo deploy

# With notifications
observ-demo deploy \
  --notify-email you@example.com \
  --notify-slack https://hooks.slack.com/...

# Auto-approve (skip confirmation)
observ-demo deploy --auto-approve
```

### 7. Access the Observability Stack

```bash
# Port-forward to access locally:

# Jaeger UI (Distributed Tracing)
kubectl port-forward -n observability svc/jaeger-query 16686:16686
# Access: http://localhost:16686

# Prometheus (Metrics)
kubectl port-forward -n observability svc/prometheus-server 9090:9090
# Access: http://localhost:9090

# Grafana (Dashboards)
kubectl port-forward -n observability svc/grafana 3000:3000
# Access: http://localhost:3000
# Credentials: admin / admin123
```

### 8. Generate Traffic

```bash
# Generate low traffic
observ-demo generate-traffic --pattern low

# Generate high traffic for 10 minutes
observ-demo generate-traffic --pattern high --duration 600
```

## CLI Commands

### Project Management
```bash
observ-demo init                    # Initialize GCP project
observ-demo configure               # Configuration wizard
observ-demo validate                # Validate prerequisites
```

### Deployment
```bash
observ-demo deploy                  # Deploy complete stack
observ-demo status                  # Check deployment status
observ-demo access                  # Get access URLs
observ-demo logs [--service NAME]   # View logs
observ-demo teardown                # Destroy all resources
```

### Cost Management
```bash
observ-demo cost --estimate         # Estimate deployment costs
observ-demo cost --current          # Show current month costs
observ-demo cost --forecast         # Project monthly costs
observ-demo cost --budget 100       # Set monthly budget
```

### Traffic Generation
```bash
observ-demo generate-traffic --pattern low      # Light traffic
observ-demo generate-traffic --pattern medium   # Moderate traffic
observ-demo generate-traffic --pattern high     # Heavy traffic
observ-demo generate-traffic --pattern spike    # Traffic spike
```

## Project Structure

```
observ-demo/
├── cli/                       # Python CLI application
│   ├── observ_demo/          # Main package
│   │   ├── cli.py            # CLI commands
│   │   ├── config.py         # Configuration models
│   │   ├── commands/         # Command implementations
│   │   ├── gcp/              # GCP integrations
│   │   ├── terraform/        # Terraform wrapper
│   │   └── notifications/    # Email/Slack alerts
│   └── tests/                # Test suite
│
├── terraform/                 # Infrastructure as Code
│   ├── modules/gcp/          # GCP modules
│   │   ├── project-setup/    # Foundation
│   │   ├── vpc-network/      # Networking
│   │   ├── gke-cluster/      # GKE Autopilot
│   │   ├── iap-config/       # IAP setup
│   │   ├── monitoring/       # Alerts
│   │   └── budget-alerts/    # Cost monitoring
│   └── environments/         # Environment configs
│
├── kubernetes/                # Kubernetes manifests
│   ├── opentelemetry/        # OpenTelemetry demo
│   └── microservices-demo/   # Microservices demo
│
├── config/                    # Configuration files
└── docs/                      # Documentation
```

## Configuration

### Example Configuration File

```yaml
gcp:
  project_id: my-observ-demo
  billing_account: 012345-6789AB-CDEF01
  region: us-central1
  zone: us-central1-a

cluster:
  name: observ-demo-cluster
  mode: autopilot
  enable_private_nodes: true
  enable_workload_identity: true

monitoring:
  email_notifications:
    - admin@example.com
  slack_webhook: https://hooks.slack.com/...
  budget_amount: 100.0
  budget_thresholds: [0.5, 0.75, 0.9, 1.0]

deployment:
  deploy_opentelemetry: true
  deploy_microservices: true
  deploy_monitoring: true
  enable_traffic_generation: true
```

## Cost Breakdown

Estimated monthly costs for 24/7 operation:

| Component | Configuration | Monthly Cost |
|-----------|---------------|--------------|
| **Infrastructure** | | |
| GKE Autopilot (Microservices) | ~2 vCPU, 4GB RAM | $25-30 |
| VPC, Cloud NAT | Standard networking | $2-5 |
| Cloud Storage (Terraform state) | < 1GB | <$1 |
| **Observability Stack** | | |
| Jaeger (all-in-one) | 512Mi-1Gi RAM, 200m-500m CPU | $8-12 |
| Prometheus + Alertmanager | 2-4Gi RAM, 500m-1000m CPU | $20-30 |
| Grafana | 256Mi-512Mi RAM, 100m-200m CPU | $5-8 |
| OpenTelemetry Collector | 512Mi-1Gi RAM, 200m-500m CPU | $5-10 |
| **Optional** | | |
| Cloud Load Balancers | If using external IPs | $18-22 |
| **TOTAL** | | **$60-80** |

**Note:** Use port-forwarding instead of load balancers to save $18-22/month.

### Cost Optimization Tips

1. **Use port-forwarding** instead of external load balancers (saves ~$20/mo)
2. **Reduce sampling** from 100% to 10% for production (minimal impact)
3. **Scale to zero** when not in use: `kubectl scale deployment -n observability --replicas=0 --all`
4. **Reduce retention** in Prometheus from 7d to 3d (saves ~$5-10/mo)
5. **Reduce trace retention** in Jaeger from 10000 to 5000 traces
6. **Set budget alerts** to avoid surprises

## Monitoring & Alerts

### SRE-Focused Observability

**Golden Signals (Grafana Dashboard):**
- **Latency**: P50, P95, P99 response times by service
- **Traffic**: Request rate (RPS) per service
- **Errors**: Error rate with threshold-based gauge (green/yellow/red)
- **Saturation**: CPU and memory utilization

**SLO Tracking (Grafana Dashboard):**
- **Availability**: 99% SLO target with gauge visualization
- **Error Rate**: <1% SLO target
- **Latency**: P95 <500ms SLO target
- **Error Budget**: 30-day burn rate tracking

### Automatic Alerts (Prometheus)
Pre-configured alerts for SLO violations:
- ✅ **HighErrorRate**: >5% error rate for 5 minutes (warning)
- ✅ **CriticalErrorRate**: >10% error rate for 2 minutes (critical)
- ✅ **HighLatencyP95**: >1s P95 latency for 5 minutes
- ✅ **HighLatencyP99**: >2s P99 latency for 5 minutes
- ✅ **LowAvailability**: <99% availability for 5 minutes (SLO violation)
- ✅ **ServiceDown**: Service unavailable for 1 minute

**Access Alerts:**
```bash
kubectl port-forward -n observability svc/prometheus-alertmanager 9093:9093
# Access: http://localhost:9093
```

### Pre-configured Dashboards (Grafana)
- **SRE Golden Signals**: Real-time monitoring of the 4 key metrics
- **SLO Tracking**: Availability, error rate, latency against SLO targets
- **Error Budget**: Visual burn rate and remaining budget
- **Service Overview**: Per-service metrics and health
- **Kubernetes Metrics**: Cluster resources (CPU, memory, pods)

## Security

### Authentication & Authorization
- **Workload Identity**: No service account keys required
- **IAP**: Zero-trust access without VPN
- **Least Privilege**: Minimal IAM permissions
- **Google Identity**: User authentication

### Network Security
- **Private Cluster**: No public node IPs
- **Cloud NAT**: Controlled egress
- **Firewall Rules**: Deny-all default
- **VPC Isolation**: Dedicated network

### Data Security
- **Encryption at Rest**: All GCS and GKE data
- **Encryption in Transit**: TLS everywhere
- **Secret Manager**: Secure credential storage
- **Audit Logging**: Full audit trails

## Troubleshooting

### Common Issues

**Issue**: `gcloud: command not found`
**Solution**: Install gcloud CLI: https://cloud.google.com/sdk/docs/install

**Issue**: `Permission denied` errors
**Solution**: Ensure you have Project Owner/Editor role and billing account access

**Issue**: `API not enabled` errors
**Solution**: Run `observ-demo init` to enable required APIs automatically

**Issue**: Deployment timeout
**Solution**: GKE cluster creation can take 10-15 minutes. Check `observ-demo status`

**Issue**: High costs
**Solution**: Run `observ-demo cost --current` and consider scaling down or tearing down

### Getting Help

1. Check the [troubleshooting documentation](docs/troubleshooting.md)
2. Review [deployment logs](docs/deployment-guide.md)
3. Run `observ-demo validate` to check configuration
4. Open an issue in the repository

## Development

### Running Tests

```bash
cd cli

# Install development dependencies
pip install -r requirements-dev.txt

# Run unit tests
pytest tests/unit/ -v

# Run integration tests (requires GCP credentials)
pytest tests/integration/ -v

# Run with coverage
pytest --cov=observ_demo --cov-report=html
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## Roadmap

### ✅ Completed
- [x] Project structure and CLI framework
- [x] Terraform infrastructure modules (VPC, GKE, IAP, monitoring, budgets)
- [x] Python CLI with commands (init, deploy, status, teardown, traffic)
- [x] **Open-source observability stack** (Jaeger, Prometheus, Grafana)
- [x] OpenTelemetry Collector deployment
- [x] Google Microservices Demo integration
- [x] **SRE dashboards** (Golden Signals, SLO tracking, error budgets)
- [x] **Prometheus alerting** for SLO violations
- [x] Traffic generation with realistic patterns
- [x] Comprehensive documentation

### 🚧 In Progress
- [ ] Additional Grafana dashboards (service-specific)
- [ ] Grafana Loki integration for log aggregation
- [ ] Advanced sampling strategies

### 🎯 Planned Enhancements
- [ ] Multi-cloud support (AWS, Azure)
- [ ] Multi-cluster observability
- [ ] Service mesh integration (Istio/Linkerd)
- [ ] Custom OpenTelemetry instrumentation examples
- [ ] CI/CD pipeline templates
- [ ] Chaos engineering scenarios
- [ ] GitOps integration (ArgoCD/Flux)
- [ ] Advanced traffic patterns (canary, blue-green)

## License

MIT License - see [LICENSE](LICENSE) file for details

## Acknowledgments

This project leverages industry-leading open-source tools:

- **[OpenTelemetry](https://opentelemetry.io/)** - Vendor-agnostic observability framework
- **[Jaeger](https://www.jaegertracing.io/)** - Distributed tracing platform (CNCF graduated project)
- **[Prometheus](https://prometheus.io/)** - Monitoring and alerting toolkit (CNCF graduated project)
- **[Grafana](https://grafana.com/)** - Observability and data visualization platform
- **[Google Microservices Demo](https://github.com/GoogleCloudPlatform/microservices-demo)** - Sample polyglot microservices application
- **[Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest)** - Infrastructure as Code for GCP
- **[kube-prometheus-stack](https://github.com/prometheus-community/helm-charts)** - Complete Prometheus operator and stack

Special thanks to the SRE and CNCF communities for their foundational work on observability standards.

## Support

For questions, issues, or contributions:
- Open an issue in the repository
- Check the [documentation](docs/)
- Review the [implementation plan](docs/architecture.md)

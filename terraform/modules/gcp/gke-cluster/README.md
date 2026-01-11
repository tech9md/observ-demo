# GKE Autopilot Cluster Module

This Terraform module creates a production-ready, cost-optimized GKE Autopilot cluster with security best practices, Workload Identity, and private node configuration.

## Features

- ✅ **GKE Autopilot** - Fully managed, pay-per-pod pricing (~60% cost savings)
- ✅ **Private Nodes** - No external IPs on nodes for enhanced security
- ✅ **Workload Identity** - Secure pod authentication without service account keys
- ✅ **Automatic Updates** - Managed through release channels
- ✅ **Security Posture** - Built-in vulnerability scanning
- ✅ **Managed Prometheus** - Integrated monitoring
- ✅ **High Availability** - Regional cluster by default
- ✅ **Network Policies** - Pod-to-pod traffic control

## Usage

### Basic Configuration

```hcl
module "gke_cluster" {
  source = "./modules/gcp/gke-cluster"

  project_id      = "my-observ-demo"
  cluster_name    = "observ-demo-cluster"
  region          = "us-central1"
  regional_cluster = true

  # Network configuration (from vpc-network module)
  network_name         = module.vpc_network.network_name
  network_self_link    = module.vpc_network.network_self_link
  subnetwork_name      = module.vpc_network.gke_subnet_name
  pods_range_name      = module.vpc_network.gke_pods_range_name
  services_range_name  = module.vpc_network.gke_services_range_name

  # Private cluster
  enable_private_nodes    = true
  enable_private_endpoint = false
  master_ipv4_cidr_block  = "172.16.0.0/28"

  # Workload Identity (from project-setup module)
  otel_service_account_email          = module.project_setup.otel_service_account_email
  microservices_service_account_email = module.project_setup.microservices_service_account_email

  # Features
  enable_vertical_pod_autoscaling = true
  enable_managed_prometheus       = true
  enable_security_posture         = true

  labels = {
    environment = "dev"
    managed-by  = "terraform"
  }
}
```

### Advanced Configuration with Master Authorized Networks

```hcl
module "gke_cluster" {
  source = "./modules/gcp/gke-cluster"

  # ... basic configuration ...

  # Restrict control plane access
  master_authorized_networks = [
    {
      cidr_block   = "10.0.0.0/8"
      display_name = "Internal network"
    },
    {
      cidr_block   = "203.0.113.0/24"
      display_name = "Office network"
    }
  ]

  # Enhanced security
  enable_binary_authorization = true
  deletion_protection         = true

  # Custom maintenance window
  maintenance_start_time = "02:00" # 2 AM UTC
  release_channel        = "STABLE"
}
```

## GKE Autopilot vs Standard

This module uses **GKE Autopilot** for several reasons:

| Feature | Autopilot | Standard |
|---------|-----------|----------|
| **Pricing** | Pay per pod resource | Pay for all nodes |
| **Cost** | ~40-60% cheaper | Higher baseline cost |
| **Management** | Fully managed | Manual node management |
| **Security** | Hardened by default | Manual hardening |
| **Scaling** | Automatic | Manual configuration |
| **Node Pools** | Managed by Google | Manual creation |

**Estimated Monthly Costs** (2 vCPU, 4GB RAM for pods):
- Autopilot: ~$25-30/month
- Standard: ~$73/month (e2-small nodes)

## Private Cluster Architecture

```
┌─────────────────────────────────────────────────┐
│ GKE Control Plane                               │
│ (Private IP: 172.16.0.0/28)                     │
│                                                 │
│ Master Authorized Networks:                     │
│ • Internal VPC                                  │
│ • Specific CIDR blocks                          │
└─────────────────┬───────────────────────────────┘
                  │ Private connection
                  │
┌─────────────────▼───────────────────────────────┐
│ GKE Worker Nodes (Private)                      │
│ • No external IPs                               │
│ • Cloud NAT for outbound                        │
│ • Internal communication only                   │
│                                                 │
│ ┌─────────────┐  ┌─────────────┐               │
│ │ Pod (10.4.x)│  │ Pod (10.4.x)│               │
│ └─────────────┘  └─────────────┘               │
└─────────────────────────────────────────────────┘
```

## Workload Identity Configuration

Workload Identity allows pods to authenticate to GCP services without service account keys.

### How It Works

1. **GCP Service Account** created in `project-setup` module
2. **Kubernetes Service Account** created in namespace
3. **IAM Binding** grants Workload Identity permission
4. **Pod Annotation** links K8s SA to GCP SA

### Kubernetes Service Account Example

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otel-collector
  namespace: otel-demo
  annotations:
    iam.gke.io/gcp-service-account: otel-collector@PROJECT_ID.iam.gserviceaccount.com
```

### Pod Configuration

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: otel-collector
  namespace: otel-demo
spec:
  serviceAccountName: otel-collector
  containers:
  - name: collector
    image: otel/opentelemetry-collector:latest
    # Pod automatically gets GCP credentials
```

## Network Configuration

### IP Ranges

| Range | CIDR | Purpose | Size |
|-------|------|---------|------|
| Nodes | 10.0.0.0/20 | GKE worker nodes | 4,091 IPs |
| Pods | 10.4.0.0/14 | Pod IP addresses | 262,144 IPs |
| Services | 10.8.0.0/20 | ClusterIP services | 4,091 IPs |
| Master | 172.16.0.0/28 | Control plane | 16 IPs |

### Cloud NAT

Private nodes use Cloud NAT for:
- Pulling container images from registries
- Accessing Google APIs (GCR, GCS, etc.)
- External API calls from applications

## Security Features

### 1. Private Nodes
- No external IPs on worker nodes
- All node traffic stays within VPC
- Reduces attack surface

### 2. Private Endpoint (Optional)
- Control plane not accessible from internet
- Access via VPN or Cloud Interconnect
- Set `enable_private_endpoint = true`

### 3. Binary Authorization (Optional)
- Only signed/verified images can run
- Integrates with Container Analysis
- Set `enable_binary_authorization = true`

### 4. Security Posture
- Automatic vulnerability scanning
- Security configuration recommendations
- Compliance monitoring

### 5. Network Policies
- Control pod-to-pod communication
- Namespace isolation
- Least privilege network access

## Monitoring and Logging

### Google Cloud Managed Prometheus

```hcl
enable_managed_prometheus = true
```

Provides:
- Automatic Prometheus metrics collection
- Managed storage and querying
- Integration with Cloud Monitoring
- No Prometheus server to manage

### Logging Configuration

Logs collected:
- **System Components** - kubelet, kube-proxy, etc.
- **Workloads** - Application logs from pods

Logs sent to:
- Cloud Logging
- Available for querying and alerting

## Accessing the Cluster

### Configure kubectl

Use the output command:

```bash
# Regional cluster
gcloud container clusters get-credentials observ-demo-cluster \
  --region us-central1 \
  --project my-observ-demo

# Zonal cluster
gcloud container clusters get-credentials observ-demo-cluster \
  --zone us-central1-a \
  --project my-observ-demo
```

### Verify Access

```bash
kubectl cluster-info
kubectl get nodes
kubectl get namespaces
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID | `string` | n/a | yes |
| cluster_name | Name of the GKE cluster | `string` | `"observ-demo-cluster"` | no |
| region | GCP region | `string` | `"us-central1"` | no |
| zone | GCP zone (for zonal clusters) | `string` | `"us-central1-a"` | no |
| regional_cluster | Create regional cluster | `bool` | `true` | no |
| network_name | VPC network name | `string` | n/a | yes |
| network_self_link | VPC network self-link | `string` | n/a | yes |
| subnetwork_name | Subnetwork name | `string` | n/a | yes |
| pods_range_name | Secondary range for pods | `string` | `"gke-pods"` | no |
| services_range_name | Secondary range for services | `string` | `"gke-services"` | no |
| enable_private_nodes | Enable private nodes | `bool` | `true` | no |
| enable_private_endpoint | Private control plane endpoint | `bool` | `false` | no |
| master_ipv4_cidr_block | CIDR for master network | `string` | `"172.16.0.0/28"` | no |
| master_authorized_networks | Authorized networks for control plane | `list(object)` | `[]` | no |
| release_channel | GKE release channel | `string` | `"REGULAR"` | no |
| maintenance_start_time | Maintenance window start time | `string` | `"03:00"` | no |
| enable_vertical_pod_autoscaling | Enable VPA | `bool` | `true` | no |
| enable_managed_prometheus | Enable managed Prometheus | `bool` | `true` | no |
| enable_binary_authorization | Enable Binary Authorization | `bool` | `false` | no |
| enable_security_posture | Enable security posture | `bool` | `true` | no |
| deletion_protection | Enable deletion protection | `bool` | `false` | no |
| otel_service_account_email | GCP SA for OpenTelemetry | `string` | `null` | no |
| otel_namespace | K8s namespace for OpenTelemetry | `string` | `"otel-demo"` | no |
| otel_service_account_name | K8s SA for OpenTelemetry | `string` | `"otel-collector"` | no |
| microservices_service_account_email | GCP SA for microservices | `string` | `null` | no |
| microservices_namespace | K8s namespace for microservices | `string` | `"microservices-demo"` | no |
| microservices_service_account_name | K8s SA for microservices | `string` | `"microservices-demo"` | no |
| labels | Resource labels | `map(string)` | `{managed-by="terraform"}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | Cluster ID |
| cluster_name | Cluster name |
| cluster_location | Cluster location (region or zone) |
| cluster_endpoint | Cluster master endpoint (sensitive) |
| cluster_ca_certificate | Cluster CA certificate (sensitive) |
| cluster_master_version | Kubernetes master version |
| workload_identity_pool | Workload Identity pool |
| kubectl_config_command | Command to configure kubectl |
| cluster_summary | Summary of cluster configuration |
| workload_identity_annotation | Annotations for Workload Identity |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| google | ~> 5.0 |

## Dependencies

This module depends on:
- **VPC Network Module** - Provides network and subnets
- **Project Setup Module** - Provides service accounts for Workload Identity

## Post-Deployment Steps

### 1. Configure kubectl

```bash
gcloud container clusters get-credentials observ-demo-cluster \
  --region us-central1 \
  --project my-observ-demo
```

### 2. Create Namespaces

```bash
kubectl create namespace otel-demo
kubectl create namespace microservices-demo
```

### 3. Create Kubernetes Service Accounts

```bash
# OpenTelemetry
kubectl create serviceaccount otel-collector -n otel-demo
kubectl annotate serviceaccount otel-collector \
  -n otel-demo \
  iam.gke.io/gcp-service-account=otel-collector@PROJECT_ID.iam.gserviceaccount.com

# Microservices
kubectl create serviceaccount microservices-demo -n microservices-demo
kubectl annotate serviceaccount microservices-demo \
  -n microservices-demo \
  iam.gke.io/gcp-service-account=microservices-demo@PROJECT_ID.iam.gserviceaccount.com
```

### 4. Verify Workload Identity

```bash
# Test from a pod
kubectl run -it test-wi \
  --image=google/cloud-sdk:slim \
  --serviceaccount=otel-collector \
  -n otel-demo \
  --command -- gcloud auth list
```

## Troubleshooting

### Cluster Creation Timeout

GKE Autopilot clusters can take 10-15 minutes to create. Increase timeouts if needed:

```hcl
timeouts {
  create = "60m"
}
```

### Cannot Access Control Plane

If using private endpoint, ensure you're accessing from:
- Authorized network (master_authorized_networks)
- VPN or Cloud Interconnect
- Bastion host in same VPC

### Workload Identity Not Working

1. Verify IAM binding exists
2. Check Kubernetes SA annotation
3. Ensure pod uses correct SA
4. Verify GCP SA has required permissions

### Node Scheduling Issues

Autopilot automatically provisions nodes. Check:
- Pod resource requests
- Tolerations and node selectors
- Resource quotas

## Cost Optimization

### Autopilot Pricing

Charged only for:
- vCPU: $0.045 per vCPU-hour
- Memory: $0.005 per GB-hour
- Ephemeral storage included

### Example Costs (24/7)

| Resources | Monthly Cost |
|-----------|--------------|
| 1 vCPU, 2GB RAM | ~$38 |
| 2 vCPU, 4GB RAM | ~$76 |
| 4 vCPU, 8GB RAM | ~$152 |

### Cost Reduction Tips

1. **Right-size pods** - Use minimal resource requests
2. **Use VPA** - Automatically optimize requests
3. **Enable autoscaling** - Scale to zero when idle
4. **Use preemptible pods** (if workload allows)
5. **Monitor usage** - Review Cloud Billing

## License

MIT License - see root LICENSE file for details.

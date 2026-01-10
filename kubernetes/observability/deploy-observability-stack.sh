#!/bin/bash
# Deploy Open Source Observability Stack
# This script deploys Jaeger, Prometheus, and Grafana for observability

set -euo pipefail

# Configuration
NAMESPACE="${OBSERVABILITY_NAMESPACE:-observability}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${CYAN}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi

    if ! command -v helm &> /dev/null; then
        print_error "helm not found. Please install Helm."
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Create namespace
create_namespace() {
    print_info "Creating namespace: $NAMESPACE"

    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_warning "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace "$NAMESPACE"
        print_success "Namespace created: $NAMESPACE"
    fi

    # Label namespace for network policies
    kubectl label namespace "$NAMESPACE" name="$NAMESPACE" --overwrite
}

# Deploy Jaeger
deploy_jaeger() {
    print_info "Deploying Jaeger (distributed tracing)..."

    kubectl apply -f jaeger-all-in-one.yaml

    # Wait for Jaeger to be ready
    print_info "Waiting for Jaeger to be ready..."
    kubectl wait --for=condition=ready pod \
        --selector=app=jaeger \
        --namespace="$NAMESPACE" \
        --timeout=300s

    print_success "Jaeger deployed successfully"
}

# Add Helm repositories
add_helm_repos() {
    print_info "Adding Helm repositories..."

    # Prometheus community charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    print_success "Helm repositories added and updated"
}

# Deploy Prometheus Stack
deploy_prometheus() {
    print_info "Deploying Prometheus (metrics and alerting)..."

    helm upgrade --install prometheus \
        prometheus-community/kube-prometheus-stack \
        --namespace "$NAMESPACE" \
        --values prometheus-values.yaml \
        --wait \
        --timeout 10m

    print_success "Prometheus deployed successfully"
}

# Deploy Grafana
deploy_grafana() {
    print_info "Deploying Grafana (visualization)..."

    kubectl apply -f grafana.yaml

    # Wait for Grafana to be ready
    print_info "Waiting for Grafana to be ready..."
    kubectl wait --for=condition=ready pod \
        --selector=app=grafana \
        --namespace="$NAMESPACE" \
        --timeout=300s

    print_success "Grafana deployed successfully"
}

# Import Grafana dashboards
import_grafana_dashboards() {
    print_info "Setting up Grafana dashboards..."

    # Create ConfigMaps for dashboards
    kubectl create configmap grafana-dashboards-sre \
        --from-file=dashboards/ \
        --namespace="$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -

    kubectl create configmap grafana-dashboards-microservices \
        --from-file=dashboards/ \
        --namespace="$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -

    print_success "Grafana dashboards configured"
}

# Display access information
display_access_info() {
    print_info "Deployment Information:"
    echo ""
    echo "Namespace: $NAMESPACE"
    echo ""

    print_info "Service Endpoints (internal):"
    echo ""
    echo "  Jaeger UI:       http://jaeger-query.${NAMESPACE}.svc.cluster.local:16686"
    echo "  Jaeger Collector: jaeger-collector.${NAMESPACE}.svc.cluster.local:14250"
    echo "  Prometheus:      http://prometheus-server.${NAMESPACE}.svc.cluster.local:9090"
    echo "  Grafana:         http://grafana.${NAMESPACE}.svc.cluster.local:3000"
    echo ""

    print_info "Access via Port Forwarding:"
    echo ""
    echo "  Jaeger UI:"
    echo "    kubectl port-forward -n $NAMESPACE svc/jaeger-query 16686:16686"
    echo "    Access: http://localhost:16686"
    echo ""
    echo "  Prometheus:"
    echo "    kubectl port-forward -n $NAMESPACE svc/prometheus-server 9090:9090"
    echo "    Access: http://localhost:9090"
    echo ""
    echo "  Grafana:"
    echo "    kubectl port-forward -n $NAMESPACE svc/grafana 3000:3000"
    echo "    Access: http://localhost:3000"
    echo "    Username: admin"
    echo "    Password: admin123"
    echo ""

    print_info "Next Steps:"
    echo "  1. Deploy OpenTelemetry Collector (it will send data to this stack)"
    echo "     cd ../opentelemetry && ./deploy.sh"
    echo ""
    echo "  2. Deploy Microservices Demo (it will generate telemetry)"
    echo "     cd ../microservices-demo && ./deploy.sh"
    echo ""
    echo "  3. Generate traffic to create demo data"
    echo "     observ-demo generate-traffic --pattern medium"
    echo ""
    echo "  4. Access Jaeger to view distributed traces"
    echo "     kubectl port-forward -n $NAMESPACE svc/jaeger-query 16686:16686"
    echo ""
    echo "  5. Access Grafana to view SRE dashboards"
    echo "     kubectl port-forward -n $NAMESPACE svc/grafana 3000:3000"
    echo ""

    print_info "Useful Commands:"
    echo "  View pods:          kubectl get pods -n $NAMESPACE"
    echo "  View services:      kubectl get svc -n $NAMESPACE"
    echo "  View Jaeger logs:   kubectl logs -n $NAMESPACE -l app=jaeger --tail=50"
    echo "  View Prometheus logs: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=prometheus --tail=50"
    echo "  View Grafana logs:  kubectl logs -n $NAMESPACE -l app=grafana --tail=50"
    echo "  Delete stack:       kubectl delete namespace $NAMESPACE"
    echo ""
}

# Main deployment flow
main() {
    echo ""
    print_info "Observability Stack Deployment (Jaeger + Prometheus + Grafana)"
    print_info "=============================================================="
    echo ""

    check_prerequisites
    create_namespace

    # Deploy in order: Jaeger → Prometheus → Grafana
    deploy_jaeger
    add_helm_repos
    deploy_prometheus
    deploy_grafana
    import_grafana_dashboards

    display_access_info

    echo ""
    print_success "Observability stack deployed successfully!"
    echo ""
}

# Run main function
main

#!/bin/bash
# Deploy OpenTelemetry Collector to GKE with GCP integration
# This script deploys ONLY the OpenTelemetry Collector (not the demo app)
# The collector receives telemetry from Microservices Demo and exports to GCP

set -euo pipefail

# Configuration
NAMESPACE="${OTEL_NAMESPACE:-opentelemetry}"
RELEASE_NAME="${OTEL_RELEASE:-otel-collector}"
CHART_VERSION="${OTEL_CHART_VERSION:-0.76.1}"
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"

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

    if [ -z "$PROJECT_ID" ]; then
        PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
        if [ -z "$PROJECT_ID" ]; then
            print_error "GCP_PROJECT_ID not set and no default project found."
            print_info "Set project: export GCP_PROJECT_ID=your-project-id"
            exit 1
        fi
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

# Add Helm repository
add_helm_repo() {
    print_info "Adding OpenTelemetry Helm repository..."

    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo update

    print_success "Helm repository added and updated"

    print_info "Available OpenTelemetry Collector versions:"
    helm search repo open-telemetry/opentelemetry-collector --versions | head -5
}

# Configure values file
configure_values() {
    print_info "Configuring Helm values for GCP..."

    # Use the collector-only values file
    TEMP_VALUES=$(mktemp)
    sed "s/PROJECT_ID/$PROJECT_ID/g" values-collector.yaml > "$TEMP_VALUES"

    echo "$TEMP_VALUES"
}

# Deploy with Helm
deploy_helm() {
    print_info "Deploying OpenTelemetry Collector with Helm..."

    VALUES_FILE=$(configure_values)

    print_info "Using chart: open-telemetry/opentelemetry-collector:$CHART_VERSION"

    helm upgrade --install "$RELEASE_NAME" \
        open-telemetry/opentelemetry-collector \
        --namespace "$NAMESPACE" \
        --version "$CHART_VERSION" \
        --values "$VALUES_FILE" \
        --wait \
        --timeout 10m

    rm -f "$VALUES_FILE"

    print_success "OpenTelemetry Collector deployed successfully"
}

# Wait for pods
wait_for_pods() {
    print_info "Waiting for pods to be ready..."

    kubectl wait --for=condition=ready pod \
        --selector=app.kubernetes.io/instance="$RELEASE_NAME" \
        --namespace="$NAMESPACE" \
        --timeout=600s

    print_success "All pods are ready"
}

# Display access information
display_access_info() {
    print_info "Deployment Information:"
    echo ""
    echo "Namespace: $NAMESPACE"
    echo "Release: $RELEASE_NAME"
    echo "Project: $PROJECT_ID"
    echo ""

    print_info "OpenTelemetry Collector Endpoints:"
    echo ""
    echo "  OTLP gRPC:  ${RELEASE_NAME}.${NAMESPACE}.svc.cluster.local:4317"
    echo "  OTLP HTTP:  ${RELEASE_NAME}.${NAMESPACE}.svc.cluster.local:4318"
    echo "  Metrics:    ${RELEASE_NAME}.${NAMESPACE}.svc.cluster.local:8888"
    echo ""

    print_info "GCP Observability:"
    echo "  Cloud Trace:      https://console.cloud.google.com/traces/list?project=$PROJECT_ID"
    echo "  Cloud Monitoring: https://console.cloud.google.com/monitoring?project=$PROJECT_ID"
    echo "  Cloud Logging:    https://console.cloud.google.com/logs?project=$PROJECT_ID"
    echo ""

    print_info "Useful Commands:"
    echo "  View pods:          kubectl get pods -n $NAMESPACE"
    echo "  View services:      kubectl get svc -n $NAMESPACE"
    echo "  View collector logs: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=opentelemetry-collector --tail=50"
    echo "  Check health:       kubectl port-forward -n $NAMESPACE svc/${RELEASE_NAME} 13133:13133"
    echo "                      curl http://localhost:13133"
    echo "  Delete collector:   helm uninstall $RELEASE_NAME -n $NAMESPACE"
    echo ""

    print_info "Next Steps:"
    echo "  1. Deploy Microservices Demo (it will send telemetry to this collector)"
    echo "  2. Configure apps to use endpoint: ${RELEASE_NAME}.${NAMESPACE}.svc.cluster.local:4317"
    echo "  3. View traces in Cloud Trace after generating traffic"
}

# Main deployment flow
main() {
    echo ""
    print_info "OpenTelemetry Collector Deployment to GKE"
    print_info "=========================================="
    echo ""

    check_prerequisites
    create_namespace
    add_helm_repo
    deploy_helm
    wait_for_pods
    display_access_info

    echo ""
    print_success "Deployment completed successfully!"
    echo ""
}

# Run main function
main

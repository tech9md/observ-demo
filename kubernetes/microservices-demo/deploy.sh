#!/bin/bash
# Deploy Google Microservices Demo (Online Boutique) to GKE
# This script deploys the microservices demo with OpenTelemetry integration

set -euo pipefail

# Configuration
NAMESPACE="${MICROSERVICES_NAMESPACE:-microservices-demo}"
RELEASE_NAME="${MICROSERVICES_RELEASE:-online-boutique}"
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"
DEPLOY_METHOD="${DEPLOY_METHOD:-helm}"  # helm or kubectl

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

    if [ "$DEPLOY_METHOD" = "helm" ] && ! command -v helm &> /dev/null; then
        print_error "helm not found. Please install Helm or use DEPLOY_METHOD=kubectl"
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

# Deploy with kubectl (official manifests)
deploy_kubectl() {
    print_info "Deploying with kubectl..."

    # Download official manifests
    MANIFEST_URL="https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/release/kubernetes-manifests.yaml"
    TEMP_MANIFEST=$(mktemp)

    print_info "Downloading manifests from GitHub..."
    curl -sSL "$MANIFEST_URL" -o "$TEMP_MANIFEST"

    # Apply manifests
    kubectl apply -f "$TEMP_MANIFEST" -n "$NAMESPACE"

    rm -f "$TEMP_MANIFEST"
    print_success "Deployment completed"
}

# Deploy with Helm
deploy_helm() {
    print_info "Deploying with Helm..."

    # Add Google's Helm repository (if exists)
    # Note: As of writing, there's no official Helm chart for microservices-demo
    # This is a placeholder for when it becomes available
    print_warning "Helm chart for microservices-demo is not officially available"
    print_info "Falling back to kubectl deployment..."
    deploy_kubectl
}

# Configure OpenTelemetry integration
configure_otel_integration() {
    print_info "Configuring OpenTelemetry integration..."

    # Check if OpenTelemetry Collector is deployed
    if ! kubectl get svc opentelemetry-collector -n opentelemetry &> /dev/null; then
        print_warning "OpenTelemetry Collector not found in 'opentelemetry' namespace"
        print_warning "Traces will not be exported to Cloud Trace"
        print_info "Deploy OpenTelemetry first: cd ../opentelemetry && ./deploy.sh"
        return
    fi

    # Patch deployments with OpenTelemetry env vars
    SERVICES=("frontend" "cartservice" "productcatalogservice" "currencyservice"
              "paymentservice" "shippingservice" "emailservice" "checkoutservice"
              "recommendationservice" "adservice")

    for service in "${SERVICES[@]}"; do
        if kubectl get deployment "$service" -n "$NAMESPACE" &> /dev/null; then
            kubectl set env deployment/"$service" -n "$NAMESPACE" \
                OTEL_EXPORTER_OTLP_ENDPOINT=http://opentelemetry-collector.opentelemetry.svc.cluster.local:4317 \
                OTEL_SERVICE_NAME="$service" \
                OTEL_RESOURCE_ATTRIBUTES="service.version=1.0.0,deployment.environment=demo" \
                --overwrite || true
        fi
    done

    print_success "OpenTelemetry integration configured"
}

# Wait for pods
wait_for_pods() {
    print_info "Waiting for pods to be ready..."

    kubectl wait --for=condition=ready pod \
        --all \
        --namespace="$NAMESPACE" \
        --timeout=600s || true

    print_success "Pods are starting up"
}

# Display access information
display_access_info() {
    print_info "Deployment Information:"
    echo ""
    echo "Namespace: $NAMESPACE"
    echo "Release: $RELEASE_NAME"
    echo "Project: $PROJECT_ID"
    echo ""

    print_info "Access URLs:"
    echo ""

    # Get LoadBalancer IP
    FRONTEND_IP=$(kubectl get svc frontend -n "$NAMESPACE" \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

    # Alternative: frontend-external service
    if [ "$FRONTEND_IP" = "pending" ]; then
        FRONTEND_IP=$(kubectl get svc frontend-external -n "$NAMESPACE" \
            -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    fi

    if [ "$FRONTEND_IP" != "pending" ]; then
        echo "Frontend: http://$FRONTEND_IP"
    else
        print_warning "Frontend LoadBalancer IP is still pending..."
        print_info "Check status: kubectl get svc -n $NAMESPACE"
    fi

    echo "Cloud Trace: https://console.cloud.google.com/traces/list?project=$PROJECT_ID"
    echo "Cloud Monitoring: https://console.cloud.google.com/monitoring?project=$PROJECT_ID"
    echo ""

    print_info "Useful Commands:"
    echo "  View pods:        kubectl get pods -n $NAMESPACE"
    echo "  View services:    kubectl get svc -n $NAMESPACE"
    echo "  View logs:        kubectl logs -n $NAMESPACE <pod-name>"
    echo "  Port forward:     kubectl port-forward -n $NAMESPACE svc/frontend 8080:80"
    echo "  Delete deployment: kubectl delete namespace $NAMESPACE"
    echo ""

    print_info "Services Deployed:"
    kubectl get pods -n "$NAMESPACE" -o wide 2>/dev/null || true
}

# Main deployment flow
main() {
    echo ""
    print_info "Google Microservices Demo Deployment to GKE"
    print_info "============================================="
    echo ""

    check_prerequisites
    create_namespace

    if [ "$DEPLOY_METHOD" = "helm" ]; then
        deploy_helm
    else
        deploy_kubectl
    fi

    configure_otel_integration
    wait_for_pods
    display_access_info

    echo ""
    print_success "Deployment completed successfully!"
    print_info "The frontend LoadBalancer may take a few minutes to get an external IP"
    echo ""
}

# Run main function
main

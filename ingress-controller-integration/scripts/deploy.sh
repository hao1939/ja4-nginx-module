#!/bin/bash
# Deployment script for JA4-enabled nginx-ingress-controller
set -e

# Configuration
IMAGE_NAME="ja4-nginx-ingress:v1.11.5"
NAMESPACE="ingress-nginx"
DEPLOYMENT_NAME="ingress-nginx-controller"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if we can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    echo_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

# Parse command line arguments
DRY_RUN=false
USE_PATCH=false
CUSTOM_IMAGE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --patch)
            USE_PATCH=true
            shift
            ;;
        --image)
            CUSTOM_IMAGE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run       Show what would be deployed without making changes"
            echo "  --patch         Use patch method instead of set image"
            echo "  --image IMAGE   Use custom image name"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
        *)
            echo_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Use custom image if provided
if [[ -n "$CUSTOM_IMAGE" ]]; then
    IMAGE_NAME="$CUSTOM_IMAGE"
fi

echo_info "Deploying JA4-enabled nginx-ingress-controller..."
echo_info "Image: $IMAGE_NAME"
echo_info "Namespace: $NAMESPACE"
echo_info "Deployment: $DEPLOYMENT_NAME"
echo ""

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo_error "Namespace '$NAMESPACE' not found!"
    echo_error "Please install nginx-ingress-controller first or create the namespace."
    exit 1
fi

# Check if deployment exists
if ! kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo_error "Deployment '$DEPLOYMENT_NAME' not found in namespace '$NAMESPACE'!"
    echo_error "Please install nginx-ingress-controller first."
    exit 1
fi

# Show current deployment image
echo_info "Current deployment image:"
kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo_warn "DRY RUN: Would update deployment image to: $IMAGE_NAME"
    exit 0
fi

# Deploy using patch or set image method
if [[ "$USE_PATCH" == "true" ]]; then
    echo_info "Applying deployment patch..."
    
    # Create temporary patch file
    PATCH_FILE=$(mktemp)
    cat > "$PATCH_FILE" << EOF
spec:
  template:
    spec:
      containers:
      - name: controller
        image: $IMAGE_NAME
EOF
    
    if kubectl patch deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" --patch-file "$PATCH_FILE"; then
        echo_info "✅ Deployment patched successfully!"
    else
        echo_error "❌ Failed to patch deployment!"
        rm -f "$PATCH_FILE"
        exit 1
    fi
    
    rm -f "$PATCH_FILE"
else
    echo_info "Updating deployment image..."
    if kubectl set image deployment/"$DEPLOYMENT_NAME" controller="$IMAGE_NAME" -n "$NAMESPACE"; then
        echo_info "✅ Deployment image updated successfully!"
    else
        echo_error "❌ Failed to update deployment image!"
        exit 1
    fi
fi

# Wait for rollout to complete
echo_info "Waiting for rollout to complete..."
if kubectl rollout status deployment/"$DEPLOYMENT_NAME" -n "$NAMESPACE" --timeout=300s; then
    echo_info "✅ Rollout completed successfully!"
else
    echo_error "❌ Rollout failed or timed out!"
    echo_info "Check pod status with: kubectl get pods -n $NAMESPACE"
    exit 1
fi

# Verify the new image is running
echo_info "Verifying deployment..."
NEW_IMAGE=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}')
echo_info "New deployment image: $NEW_IMAGE"

# Check if pods are running
RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=ingress-nginx,app.kubernetes.io/component=controller --field-selector=status.phase=Running --no-headers | wc -l)
if [[ "$RUNNING_PODS" -gt 0 ]]; then
    echo_info "✅ $RUNNING_PODS pod(s) running successfully!"
else
    echo_error "❌ No running pods found!"
    echo_info "Check pod logs with: kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=controller"
    exit 1
fi

# Optional: Apply JA4 configuration
echo_info "Applying JA4 configuration examples (optional)..."
if [[ -f "kubernetes/configmap-examples.yaml" ]]; then
    echo_info "Applying ConfigMap examples..."
    kubectl apply -f kubernetes/configmap-examples.yaml
fi

echo ""
echo_info "🎉 Deployment completed successfully!"
echo_info "Next steps:"
echo_info "  1. Test JA4 functionality: ./scripts/test-ja4.sh"
echo_info "  2. Apply custom configurations from kubernetes/ directory"
echo_info "  3. Monitor logs: kubectl logs -f -n $NAMESPACE -l app.kubernetes.io/component=controller"
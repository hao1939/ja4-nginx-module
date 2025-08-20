#!/bin/bash
# Build script for JA4-enabled nginx-ingress-controller
set -e

# Configuration
IMAGE_NAME="ja4-nginx-ingress"
IMAGE_TAG="v1.11.5"
DOCKERFILE="docker/Dockerfile.ingress-controller"

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

# Check if we're in the right directory
if [[ ! -f "$DOCKERFILE" ]]; then
    echo_error "Dockerfile not found at $DOCKERFILE"
    echo_error "Please run this script from the ingress-controller-integration directory"
    exit 1
fi

# Check Docker is available
if ! command -v docker &> /dev/null; then
    echo_error "Docker not found. Please install Docker first."
    exit 1
fi

# Parse command line arguments
PUSH_IMAGE=false
CUSTOM_TAG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --push)
            PUSH_IMAGE=true
            shift
            ;;
        --tag)
            CUSTOM_TAG="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --push          Push the image to registry after building"
            echo "  --tag TAG       Use custom tag instead of default"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
        *)
            echo_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Use custom tag if provided
if [[ -n "$CUSTOM_TAG" ]]; then
    IMAGE_TAG="$CUSTOM_TAG"
fi

FULL_IMAGE_NAME="$IMAGE_NAME:$IMAGE_TAG"

echo_info "Starting build of JA4-enabled nginx-ingress-controller..."
echo_info "Image: $FULL_IMAGE_NAME"
echo_info "Dockerfile: $DOCKERFILE"
echo ""

# Build the image
echo_info "Building Docker image..."
if docker build -f "$DOCKERFILE" -t "$FULL_IMAGE_NAME" .; then
    echo_info "✅ Build completed successfully!"
else
    echo_error "❌ Build failed!"
    exit 1
fi

# Verify the build includes JA4
echo_info "Verifying JA4 integration..."
if docker run --rm "$FULL_IMAGE_NAME" /usr/local/bin/verify-ja4.sh; then
    echo_info "✅ JA4 verification passed!"
else
    echo_error "❌ JA4 verification failed!"
    exit 1
fi

# Show image info
echo_info "Image built successfully:"
docker images "$IMAGE_NAME" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# Push if requested
if [[ "$PUSH_IMAGE" == "true" ]]; then
    echo_info "Pushing image to registry..."
    if docker push "$FULL_IMAGE_NAME"; then
        echo_info "✅ Image pushed successfully!"
    else
        echo_error "❌ Failed to push image!"
        exit 1
    fi
fi

echo ""
echo_info "🎉 Build process completed!"
echo_info "Next steps:"
echo_info "  1. Deploy with: ./scripts/deploy.sh"
echo_info "  2. Test with: ./scripts/test-ja4.sh"
echo_info "  3. Or manually deploy: kubectl set image deployment/ingress-nginx-controller controller=$FULL_IMAGE_NAME -n ingress-nginx"
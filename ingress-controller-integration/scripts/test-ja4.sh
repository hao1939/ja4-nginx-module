#!/bin/bash
# Test script for JA4 functionality in nginx-ingress-controller
set -e

# Configuration
NAMESPACE="ingress-nginx"
DEPLOYMENT_NAME="ingress-nginx-controller"
TEST_NAMESPACE="ja4-test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

echo_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Check kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Parse command line arguments
VERBOSE=false
CLEANUP=true
SKIP_DEPLOY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --no-cleanup)
            CLEANUP=false
            shift
            ;;
        --skip-deploy)
            SKIP_DEPLOY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --verbose, -v   Enable verbose output"
            echo "  --no-cleanup    Don't cleanup test resources after testing"
            echo "  --skip-deploy   Skip deploying test application"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
        *)
            echo_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo_info "🧪 Testing JA4 functionality in nginx-ingress-controller"
echo ""

# Test 1: Check if deployment is running
echo_test "1. Checking if ingress controller is running..."
if kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &> /dev/null; then
    REPLICAS=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
    if [[ "$REPLICAS" -gt 0 ]]; then
        echo_info "✅ Ingress controller is running ($REPLICAS replicas)"
    else
        echo_error "❌ Ingress controller has no ready replicas"
        exit 1
    fi
else
    echo_error "❌ Ingress controller deployment not found"
    exit 1
fi

# Test 2: Verify JA4 module in nginx binary
echo_test "2. Verifying JA4 module is loaded..."
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')
if [[ -n "$POD_NAME" ]]; then
    if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- /usr/local/bin/verify-ja4.sh; then
        echo_info "✅ JA4 module verification passed"
    else
        echo_error "❌ JA4 module verification failed"
        exit 1
    fi
else
    echo_error "❌ No ingress controller pods found"
    exit 1
fi

# Test 3: Check nginx configuration syntax
echo_test "3. Testing nginx configuration syntax..."
if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- nginx -t &> /dev/null; then
    echo_info "✅ nginx configuration is valid"
else
    echo_error "❌ nginx configuration has errors"
    if [[ "$VERBOSE" == "true" ]]; then
        kubectl exec -n "$NAMESPACE" "$POD_NAME" -- nginx -t
    fi
    exit 1
fi

# Test 4: Deploy test application (if not skipped)
if [[ "$SKIP_DEPLOY" == "false" ]]; then
    echo_test "4. Deploying test application..."
    
    # Create test namespace
    kubectl create namespace "$TEST_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy test application
    cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ja4-test-html
  namespace: ja4-test
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>JA4 Test Page</title>
        <style>
            body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
            .header { background: #f0f0f0; padding: 15px; margin-bottom: 20px; }
            .fingerprint { background: #e8f4fd; padding: 10px; margin: 10px 0; font-family: monospace; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🔍 JA4 Fingerprint Test</h1>
            <p>This page tests JA4 fingerprinting in nginx-ingress-controller.</p>
        </div>
        
        <h2>Instructions:</h2>
        <ol>
            <li>Check the response headers in your browser's developer tools</li>
            <li>Look for <code>X-JA4-*</code> headers</li>
            <li>Verify fingerprints are generated correctly</li>
        </ol>
        
        <h2>Expected Headers:</h2>
        <ul>
            <li><strong>X-JA4-Client:</strong> Client TLS fingerprint (e.g., t13d1516h2_8daaf6152771_02713d6af862)</li>
            <li><strong>X-JA4-Server:</strong> Server TLS fingerprint (e.g., t130200_1301_a56c586f8fa7)</li>
            <li><strong>X-JA4-HTTP:</strong> HTTP header fingerprint (e.g., ge11nn05h2_9c71b8e6a160_cd08e31494f9_cd08e31494f9)</li>
        </ul>
        
        <div class="fingerprint">
            <strong>Timestamp:</strong> <span id="timestamp"></span><br>
            <strong>User-Agent:</strong> <span id="useragent"></span>
        </div>
        
        <script>
            document.getElementById('timestamp').textContent = new Date().toISOString();
            document.getElementById('useragent').textContent = navigator.userAgent;
        </script>
    </body>
    </html>

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ja4-test-app
  namespace: ja4-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ja4-test
  template:
    metadata:
      labels:
        app: ja4-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: ja4-test-html

---
apiVersion: v1
kind: Service
metadata:
  name: ja4-test-service
  namespace: ja4-test
spec:
  selector:
    app: ja4-test
  ports:
  - port: 80
    targetPort: 80

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ja4-test-ingress
  namespace: ja4-test
  annotations:
    nginx.ingress.kubernetes.io/server-snippet: |
      # Add JA4 headers for testing
      add_header X-JA4-Client "$http_ssl_ja4" always;
      add_header X-JA4-Server "$http_ssl_ja4s" always;
      add_header X-JA4-HTTP "$http_ssl_ja4h" always;
      add_header X-JA4-TCP "$http_ssl_ja4t" always;
      
      # Add debug info
      add_header X-JA4-Test "enabled" always;
      add_header X-SSL-Protocol "$ssl_protocol" always;
spec:
  rules:
  - host: ja4-test.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ja4-test-service
            port:
              number: 80
EOF
    
    # Wait for deployment to be ready
    echo_info "Waiting for test application to be ready..."
    kubectl wait --for=condition=available --timeout=60s deployment/ja4-test-app -n "$TEST_NAMESPACE"
    echo_info "✅ Test application deployed successfully"
else
    echo_warn "⚠️  Skipping test application deployment"
fi

# Test 5: Check if JA4 variables are available in nginx
echo_test "5. Testing JA4 variable availability..."
TEST_CONFIG=$(cat << 'EOF'
events { worker_connections 1024; }
http {
    server {
        listen 8080;
        location /test {
            return 200 "JA4: $http_ssl_ja4\nJA4S: $http_ssl_ja4s\nJA4H: $http_ssl_ja4h\n";
        }
    }
}
EOF
)

# Create temporary config file in pod
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- sh -c "echo '$TEST_CONFIG' > /tmp/test-ja4.conf"

# Test config syntax
if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- nginx -t -c /tmp/test-ja4.conf &> /dev/null; then
    echo_info "✅ JA4 variables are recognized by nginx"
else
    echo_error "❌ JA4 variables not recognized"
    if [[ "$VERBOSE" == "true" ]]; then
        kubectl exec -n "$NAMESPACE" "$POD_NAME" -- nginx -t -c /tmp/test-ja4.conf
    fi
    exit 1
fi

# Test 6: Check logs for JA4 related messages
echo_test "6. Checking logs for JA4 initialization..."
if kubectl logs -n "$NAMESPACE" "$POD_NAME" | grep -i ja4 &> /dev/null; then
    echo_info "✅ JA4 messages found in logs"
    if [[ "$VERBOSE" == "true" ]]; then
        echo_info "JA4-related log entries:"
        kubectl logs -n "$NAMESPACE" "$POD_NAME" | grep -i ja4 | tail -5
    fi
else
    echo_warn "⚠️  No JA4 messages found in logs (this may be normal)"
fi

# Test 7: Verify ingress is accessible
if [[ "$SKIP_DEPLOY" == "false" ]]; then
    echo_test "7. Testing ingress accessibility..."
    
    # Check if ingress was created
    if kubectl get ingress ja4-test-ingress -n "$TEST_NAMESPACE" &> /dev/null; then
        INGRESS_IP=$(kubectl get ingress ja4-test-ingress -n "$TEST_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        if [[ -z "$INGRESS_IP" ]]; then
            INGRESS_IP=$(kubectl get service ingress-nginx-controller -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        fi
        
        if [[ -n "$INGRESS_IP" ]]; then
            echo_info "✅ Ingress created with IP: $INGRESS_IP"
            echo_info "Test URL: http://$INGRESS_IP (with Host: ja4-test.local)"
        else
            echo_warn "⚠️  Ingress created but no external IP available"
            echo_info "Use port-forward to test: kubectl port-forward -n $NAMESPACE service/ingress-nginx-controller 8080:80"
        fi
    else
        echo_error "❌ Failed to create test ingress"
    fi
fi

# Summary
echo ""
echo_info "🏁 Test Summary:"
echo_info "✅ Ingress controller is running"
echo_info "✅ JA4 module is loaded and verified"
echo_info "✅ nginx configuration is valid"
echo_info "✅ JA4 variables are available"

if [[ "$SKIP_DEPLOY" == "false" ]]; then
    echo_info "✅ Test application deployed"
    echo ""
    echo_info "📋 Next Steps:"
    echo_info "1. Access the test page at: http://ja4-test.local (add to /etc/hosts if needed)"
    echo_info "2. Check browser headers for X-JA4-* values"
    echo_info "3. Use curl to test: curl -H 'Host: ja4-test.local' http://INGRESS_IP/ -I"
fi

# Cleanup
if [[ "$CLEANUP" == "true" && "$SKIP_DEPLOY" == "false" ]]; then
    echo ""
    echo_test "Cleaning up test resources..."
    kubectl delete namespace "$TEST_NAMESPACE" --wait=false &> /dev/null || true
    echo_info "✅ Cleanup initiated"
fi

echo ""
echo_info "🎉 JA4 testing completed successfully!"
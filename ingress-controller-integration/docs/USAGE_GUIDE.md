# Building and Using JA4-Enabled nginx-ingress-controller

## Quick Start

### Build the Image
```bash
# Build the custom nginx-ingress-controller with JA4 support
docker build -f Dockerfile.ingress-controller -t ja4-nginx-ingress:v1.11.5 .

# Verify the build
docker run --rm ja4-nginx-ingress:v1.11.5 /usr/local/bin/verify-ja4.sh
```

### Deploy to Kubernetes

1. **Replace the ingress controller image:**
```bash
kubectl set image deployment/ingress-nginx-controller \
  controller=ja4-nginx-ingress:v1.11.5 \
  -n ingress-nginx
```

2. **Or modify your ingress controller YAML:**
```yaml
spec:
  template:
    spec:
      containers:
      - name: controller
        image: ja4-nginx-ingress:v1.11.5
```

## Configuration Examples

### 1. Enable JA4 Logging
Create a ConfigMap to add JA4 fingerprints to access logs:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  log-format-upstream: |
    $remote_addr - $remote_user [$time_local] "$request" 
    $status $body_bytes_sent "$http_referer" "$http_user_agent"
    "ja4=$http_ssl_ja4" "ja4s=$http_ssl_ja4s" "ja4h=$http_ssl_ja4h"
  
  # Optional: Enable debug logging for JA4 module
  error-log-level: "debug"
```

### 2. Add JA4 Headers to Responses
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration  
  namespace: ingress-nginx
data:
  server-snippet: |
    # Add JA4 fingerprint headers (be careful about exposing these)
    add_header X-JA4-Client $http_ssl_ja4 always;
    add_header X-JA4-Server $http_ssl_ja4s always;
    
    # Only add for internal/debug purposes
    add_header X-Debug-JA4H $http_ssl_ja4h always;
```

### 3. Route Based on JA4 Fingerprints
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx  
data:
  server-snippet: |
    # Block known malicious JA4 fingerprints
    if ($http_ssl_ja4 ~ "^t13d.*_suspicious_pattern") {
      return 403 "Blocked by JA4 fingerprint";
    }
    
    # Route mobile clients differently based on JA4H  
    if ($http_ssl_ja4h ~ ".*mobile.*") {
      set $mobile_detected 1;
    }
```

### 4. Ingress Annotation Example
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ja4-demo-ingress
  annotations:
    nginx.ingress.kubernetes.io/server-snippet: |
      # Log JA4 data for this specific ingress
      access_log /var/log/nginx/ja4-access.log 
        '$remote_addr - "$request" ja4="$http_ssl_ja4" ja4s="$http_ssl_ja4s"';
      
      # Add JA4 data to upstream requests
      proxy_set_header X-JA4-Fingerprint $http_ssl_ja4;
spec:
  rules:
  - host: demo.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: demo-service
            port:
              number: 80
```

## Available JA4 Variables

The following nginx variables are available for use in configurations:

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `$http_ssl_ja4` | Standard JA4 client fingerprint | `t13d1516h2_8daaf6152771_02713d6af862` |
| `$http_ssl_ja4_string` | Raw JA4 components | `t,13,d,1516,h2\|4865-4866-4867\|0-23-35-13-5-18-16-0-17513-45-43-10-11-27-21` |  
| `$http_ssl_ja4one` | JA4 without PSK extensions | `t13d1516h2_8daaf6152771_b0da82dd1658` |
| `$http_ssl_ja4s` | Server JA4 fingerprint | `t130200_1301_a56c586f8fa7` |
| `$http_ssl_ja4s_string` | Raw JA4S components | `t,13,02,00\|1301\|h2` |
| `$http_ssl_ja4h` | HTTP header fingerprint | `ge11nn05h2_9c71b8e6a160_cd08e31494f9_cd08e31494f9` |
| `$http_ssl_ja4h_string` | Raw JA4H components | `GET,11,n,n,05,en\|accept,host,user-agent,accept-encoding,accept-language` |
| `$http_ssl_ja4t` | TCP fingerprint | `1460,64240,1,3,8,1,4` |
| `$http_ssl_ja4t_string` | Raw JA4T components | `1460_64240_01030804` |

## Testing the Integration

### 1. Verify Module Loading
```bash
# Check if JA4 module is loaded
kubectl exec -it deployment/ingress-nginx-controller -n ingress-nginx -- \
  /usr/local/bin/verify-ja4.sh
```

### 2. Test JA4 Variables  
Create a test endpoint that shows JA4 data:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ja4-test-page
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>JA4 Test</title></head>
    <body>
      <h1>JA4 Fingerprint Test</h1>
      <p>This page will show your JA4 fingerprints in the response headers.</p>
      <p>Check the X-JA4-* headers in your browser's developer tools.</p>
    </body>
    </html>

---
apiVersion: v1
kind: Service  
metadata:
  name: ja4-test-service
spec:
  selector:
    app: ja4-test
  ports:
  - port: 80
    targetPort: 80

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ja4-test
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
        - name: content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: content
        configMap:
          name: ja4-test-page

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ja4-test-ingress
  annotations:
    nginx.ingress.kubernetes.io/server-snippet: |
      add_header X-JA4-Client "$http_ssl_ja4" always;
      add_header X-JA4-Server "$http_ssl_ja4s" always;  
      add_header X-JA4-HTTP "$http_ssl_ja4h" always;
      add_header X-JA4-TCP "$http_ssl_ja4t" always;
spec:
  rules:
  - host: ja4-test.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ja4-test-service
            port:
              number: 80
```

### 3. Monitor JA4 Logs
```bash
# Watch access logs with JA4 data
kubectl logs -f deployment/ingress-nginx-controller -n ingress-nginx | grep ja4
```

## Troubleshooting

### Common Issues

1. **Module not loading**: Check nginx error logs for module loading errors
2. **Variables empty**: Ensure SSL/TLS is properly configured  
3. **Performance impact**: Monitor SSL handshake latency
4. **Memory usage**: JA4 processing may increase memory usage

### Debug Commands
```bash
# Check nginx configuration
kubectl exec -it deployment/ingress-nginx-controller -n ingress-nginx -- nginx -t

# Verify JA4 variables are registered  
kubectl exec -it deployment/ingress-nginx-controller -n ingress-nginx -- \
  nginx -V 2>&1 | grep ja4

# Check module loading in error log
kubectl logs deployment/ingress-nginx-controller -n ingress-nginx | grep -i ja4
```

## Security Considerations

- **Header Exposure**: Be careful about exposing JA4 fingerprints in public-facing headers
- **Performance**: JA4 processing adds computational overhead to SSL handshakes
- **Privacy**: JA4 fingerprints can potentially identify users/devices
- **Rate Limiting**: Consider rate limiting based on JA4 patterns for DDoS protection

## Build Options

The Dockerfile supports these build arguments:

```bash
# Custom versions
docker build -f Dockerfile.ingress-controller \
  --build-arg NGINX_VERSION=1.25.5 \
  --build-arg OPENSSL_VERSION=3.3.3 \  
  --build-arg JA4_MODULE_VERSION=v1.3.0-beta \
  -t ja4-nginx-ingress:custom .
```
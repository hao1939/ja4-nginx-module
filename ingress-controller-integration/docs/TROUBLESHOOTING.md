# Troubleshooting Guide for JA4 nginx-ingress-controller

## Common Issues and Solutions

### 1. Build Issues

#### Problem: "JA4 module not found in build"
```
❌ JA4 module not found in build
```

**Solutions:**
- Verify JA4 module source is available: `ls -la ja4-nginx-module/src/`
- Check nginx configure output for module inclusion
- Ensure patches applied successfully

**Debug commands:**
```bash
# Check if patches were applied
docker run --rm ja4-nginx-ingress:v1.11.5 nginx -V 2>&1 | grep ja4

# Verify module files exist
docker run --rm ja4-nginx-ingress:v1.11.5 ls -la /tmp/build/ja4-nginx-module/src/
```

#### Problem: OpenSSL/nginx patch failures
```
patch: **** malformed patch at line X
```

**Solutions:**
- Check OpenSSL/nginx versions match JA4 requirements
- Verify patch files are not corrupted
- Try with exact versions specified in JA4 documentation

#### Problem: ModSecurity compilation errors
**Solutions:**
```bash
# Install additional dependencies
RUN apk add --no-cache autoconf automake libtool pkgconfig curl-dev libxml2-dev yajl-dev

# Or disable ModSecurity in Dockerfile if not needed
# Remove: --add-dynamic-module=/tmp/build/ModSecurity-nginx
```

### 2. Deployment Issues

#### Problem: Pods crashing or not starting
```
CrashLoopBackOff
```

**Debug steps:**
```bash
# Check pod logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Check nginx configuration
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- nginx -t

# Verify JA4 module loading
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- /usr/local/bin/verify-ja4.sh
```

**Common causes:**
- nginx configuration syntax errors due to JA4 variables
- Missing SSL certificates
- Resource constraints (CPU/Memory)

#### Problem: Image pull failures
```
Failed to pull image "ja4-nginx-ingress:v1.11.5"
```

**Solutions:**
```bash
# Check if image exists locally
docker images ja4-nginx-ingress

# Re-tag for your registry
docker tag ja4-nginx-ingress:v1.11.5 your-registry/ja4-nginx-ingress:v1.11.5
docker push your-registry/ja4-nginx-ingress:v1.11.5

# Update deployment
kubectl set image deployment/ingress-nginx-controller controller=your-registry/ja4-nginx-ingress:v1.11.5 -n ingress-nginx
```

### 3. JA4 Variable Issues

#### Problem: JA4 variables are empty
```
JA4: (empty)
JA4S: (empty)
```

**Debug steps:**
```bash
# Check SSL/TLS is working
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- \
  openssl s_client -connect localhost:443 -servername test.local

# Verify variables are registered
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- \
  nginx -T | grep -i ja4

# Check SSL context
curl -k -H "Host: test.local" https://your-ingress-ip/ -I
```

**Common causes:**
- Non-SSL requests (JA4 requires TLS)
- Missing SNI (Server Name Indication)
- Client doesn't support required TLS versions

#### Problem: JA4 values appear malformed
```
JA4: t13d1516h2_000000000000_000000000000
```

**Possible causes:**
- Incomplete SSL handshake
- Client using unsupported cipher suites
- Patch version mismatch

### 4. Performance Issues

#### Problem: High SSL handshake latency
**Monitoring:**
```bash
# Check SSL handshake time
curl -w "@curl-format.txt" -o /dev/null -s https://your-site.com/

# Format file (curl-format.txt):
# time_namelookup:  %{time_namelookup}s
# time_connect:     %{time_connect}s  
# time_appconnect:  %{time_appconnect}s
# time_pretransfer: %{time_pretransfer}s
```

**Solutions:**
- Increase worker connections
- Enable SSL session reuse
- Consider disabling JA4 for high-traffic endpoints

#### Problem: High memory usage
**Monitoring:**
```bash
# Check memory usage
kubectl top pods -n ingress-nginx

# Check nginx worker memory
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- \
  ps aux | grep nginx
```

**Solutions:**
```yaml
# Increase memory limits
resources:
  limits:
    memory: 1Gi  # Increase from default
  requests:
    memory: 512Mi
```

### 5. Configuration Issues

#### Problem: nginx configuration test fails
```
nginx: [error] invalid condition "JA4" in /etc/nginx/nginx.conf:123
```

**Solutions:**
- Check variable names: `$http_ssl_ja4` not `$JA4`
- Verify quotes in nginx config
- Test configuration syntax before applying

#### Problem: Headers not appearing in responses
**Debug:**
```bash
# Test with curl
curl -H "Host: test.local" https://your-ingress-ip/ -I

# Check nginx access logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller | grep test.local

# Verify server-snippet syntax
kubectl get ingress your-ingress -o yaml | grep -A 10 server-snippet
```

### 6. Testing and Validation

#### Problem: Test script failures
```bash
# Run with verbose output
./scripts/test-ja4.sh --verbose

# Skip deployment if it exists
./scripts/test-ja4.sh --skip-deploy

# Keep test resources for debugging
./scripts/test-ja4.sh --no-cleanup
```

#### Problem: JA4 values don't match expected patterns
**Validation:**
```bash
# Compare with reference implementation
curl -k -H "Host: test.local" https://your-ingress-ip/ -v 2>&1 | grep -i tls

# Check client capabilities
openssl s_client -connect your-ingress-ip:443 -servername test.local -msg
```

## Debug Configuration

Add this to your ConfigMap for enhanced debugging:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  error-log-level: "debug"
  server-snippet: |
    # Debug endpoint
    location /debug/ja4-status {
        return 200 'JA4 Status:
        
    Module loaded: OK
    Variables available:
    - http_ssl_ja4: $http_ssl_ja4
    - http_ssl_ja4s: $http_ssl_ja4s  
    - http_ssl_ja4h: $http_ssl_ja4h
    - http_ssl_ja4t: $http_ssl_ja4t
    
    SSL Context:
    - Protocol: $ssl_protocol
    - Cipher: $ssl_cipher
    - Server Name: $ssl_server_name
    
    Request Info:
    - Remote IP: $remote_addr
    - Time: $time_iso8601
    ';
        add_header Content-Type text/plain;
    }
```

## Getting Help

1. **Check logs first:**
   ```bash
   kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
   ```

2. **Verify JA4 module:**
   ```bash
   kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- \
     /usr/local/bin/verify-ja4.sh
   ```

3. **Test configuration:**
   ```bash
   kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- nginx -t
   ```

4. **Run comprehensive test:**
   ```bash
   ./scripts/test-ja4.sh --verbose
   ```

## Known Limitations

- JA4 only works with TLS/SSL connections
- Some client libraries may not generate complete fingerprints  
- Performance impact on high-traffic systems
- Beta software with potential bugs
- Limited to specific nginx/OpenSSL versions
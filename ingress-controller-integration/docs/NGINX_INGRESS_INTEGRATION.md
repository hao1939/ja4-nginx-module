# JA4 Integration with Microsoft nginx-ingress-controller

## Analysis Summary

### Base Image Details
- **Image**: `mcr.microsoft.com/oss/kubernetes/ingress/nginx-ingress-controller:v1.11.5`
- **Base OS**: Alpine Linux 3.21.3
- **nginx Version**: 1.25.5
- **OpenSSL Version**: 3.3.3
- **Architecture**: amd64
- **User**: www-data (UID 101)

### Version Compatibility Challenges

| Component | Ingress Controller | JA4 Module Target | Status |
|-----------|-------------------|-------------------|---------|
| nginx     | 1.25.5           | 1.24.0           | ⚠️ Minor version diff |
| OpenSSL   | 3.3.3            | 3.2.1            | ⚠️ Minor version diff |
| Base OS   | Alpine 3.21      | Alpine (any)     | ✅ Compatible |

### Existing Modules in nginx-ingress-controller

The ingress controller includes these modules that we must preserve:
- `ngx_devel_kit` (static)
- `set-misc-nginx-module` (static)  
- `headers-more-nginx-module` (static)
- `ngx_http_substitutions_filter_module` (static)
- `lua-nginx-module` (static)
- `stream-lua-nginx-module` (static)
- `lua-upstream-nginx-module` (static)
- `nginx-http-auth-digest` (dynamic)
- `ModSecurity-nginx` (dynamic)
- `ngx_http_geoip2_module` (dynamic)
- `ngx_brotli` (dynamic)

### Integration Strategy

1. **Multi-stage Build**: Use builder stage to compile nginx with JA4 and all existing modules
2. **Patch Compatibility**: Apply JA4 patches to newer OpenSSL/nginx versions
3. **Module Preservation**: Maintain all existing ingress controller functionality
4. **Runtime Replacement**: Replace nginx binary in final image while preserving other components

### Required Patches

JA4 module requires patches to:
- **OpenSSL**: Add client features extraction (`patches/openssl.patch`)
- **nginx**: Add SSL client features function (`patches/nginx.patch`)

### Build Configuration Match

The new build must match the original configure arguments:
```bash
--prefix=/usr/local/nginx 
--conf-path=/etc/nginx/nginx.conf 
--modules-path=/etc/nginx/modules 
--with-debug --with-compat --with-pcre-jit
--with-http_ssl_module --with-http_v2_module --with-http_v3_module
--with-stream --with-stream_ssl_module
# ... plus all existing modules + JA4
```

## Testing Requirements

1. **Functionality**: Verify all ingress controller features work
2. **JA4 Variables**: Test `$http_ssl_ja4*` variables are available
3. **Performance**: Monitor SSL handshake performance impact
4. **Kubernetes**: Test in actual ingress controller deployment

## Usage Examples

### ConfigMap for JA4 Logging
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
    JA4="$http_ssl_ja4" JA4S="$http_ssl_ja4s" JA4H="$http_ssl_ja4h"
```

### Custom Headers
```yaml
data:
  server-snippet: |
    add_header X-JA4-Fingerprint $http_ssl_ja4 always;
    add_header X-JA4S-Server $http_ssl_ja4s always;
```

## Risk Assessment

- **High**: Binary compatibility between nginx versions
- **Medium**: OpenSSL patch compatibility with newer version  
- **Medium**: Module interaction conflicts
- **Low**: Alpine package compatibility
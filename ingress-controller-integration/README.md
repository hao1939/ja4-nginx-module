# JA4 nginx-ingress-controller Integration

This directory contains everything needed to build and deploy an nginx-ingress-controller with JA4 fingerprinting support.

## 📁 Directory Structure

```
ingress-controller-integration/
├── README.md                    # This file - overview and quick start
├── docker/
│   ├── Dockerfile              # Multi-stage build for JA4-enabled ingress controller
│   └── docker-compose.yml      # Development environment
├── kubernetes/
│   ├── configmap-examples.yaml # ConfigMap examples for JA4 logging/headers
│   ├── ingress-examples.yaml   # Ingress resources with JA4 annotations
│   ├── test-deployment.yaml    # Test application for JA4 validation
│   └── deployment-patch.yaml   # Patch existing ingress controller deployment
├── docs/
│   ├── INTEGRATION_ANALYSIS.md # Technical analysis and compatibility notes
│   ├── USAGE_GUIDE.md          # Complete usage guide with examples
│   └── TROUBLESHOOTING.md      # Common issues and solutions
└── scripts/
    ├── build.sh                # Automated build script
    ├── deploy.sh               # Kubernetes deployment script
    └── test-ja4.sh             # Validation and testing script
```

## 🚀 Quick Start

### 1. Build the Image
```bash
cd ingress-controller-integration
./scripts/build.sh
```
**⚠️ Known Issue**: Full ingress-controller build currently fails due to ModSecurity-Lua compatibility issues. Use the basic JA4 nginx build from the root directory instead:
```bash
cd .. && docker build -t ja4-nginx:source .
```

### 2. Deploy to Kubernetes
```bash
# Deploy new ingress controller with JA4
./scripts/deploy.sh

# Or patch existing deployment
kubectl patch deployment ingress-nginx-controller -n ingress-nginx --patch-file kubernetes/deployment-patch.yaml
```
**Note**: Deployment currently requires the basic JA4 nginx build due to build limitations.

### 3. Test JA4 Functionality
```bash
./scripts/test-ja4.sh
```

## 📋 Prerequisites

- Docker for building the image
- Kubernetes cluster with nginx-ingress-controller
- `kubectl` configured for your cluster

## 🔧 Available JA4 Variables

| Variable | Description | Use Case | Test Status |
|----------|-------------|----------|-------------|
| `$http_ssl_ja4` | Standard JA4 client fingerprint | Bot detection, client identification | ✅ **Verified** - Working |
| `$http_ssl_ja4s` | Server JA4 fingerprint | Server configuration tracking | ⚠️ **Empty** in tests |
| `$http_ssl_ja4h` | HTTP header fingerprint | User-Agent spoofing detection | ✅ **Verified** - Working |
| `$http_ssl_ja4t` | TCP fingerprint | Network-level client identification | ⚠️ **Empty** in tests |
| `$http_ssl_ja4x` | X.509 certificate fingerprint | Certificate-based identification | ⚠️ **Empty** in tests |
| `$http_ssl_ja4_string` | Raw JA4 string components | Debugging/analysis | ✅ **Verified** - Working |

### Test Results Summary
- ✅ **JA4 Client Detection**: Successfully distinguishes different TLS clients
  - curl: `t13d3112h2_e8f1e7e78f70_b26ce05bbdd6`
  - wget: `t13d751100_479067518aa3_fb8d5ffd48c1`
- ✅ **HTTP Fingerprinting**: JA4H generates unique fingerprints per client
- ✅ **Variable Integration**: All variables accessible in nginx config and logs
- ✅ **TLS 1.3 Support**: Tested and working with modern TLS versions

## 📚 Documentation

- **[Integration Analysis](docs/INTEGRATION_ANALYSIS.md)** - Technical details and compatibility
- **[Usage Guide](docs/USAGE_GUIDE.md)** - Complete configuration examples  
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

## 🧪 Manual Testing (Alternative to Failed Build)

Since the full ingress-controller build fails, you can test JA4 functionality using the basic module:

### 1. Build and Run Basic JA4 Nginx
```bash
# From project root
docker build -t ja4-nginx:source .
docker run -d --name ja4-test -p 8443:443 -p 8080:80 ja4-nginx:source
```

### 2. Test JA4 Fingerprinting
```bash
# Test with curl (generates one fingerprint)
curl -k https://localhost:8443/ja4

# Test with wget (generates different fingerprint)
wget --no-check-certificate -qO- https://localhost:8443/ja4
```

### 3. Expected Output
```json
{
  "ja4": "t13d3112h2_e8f1e7e78f70_b26ce05bbdd6",
  "ja4h": "ge11nn030000_b51846f30ce9_e3b0c44298fc_e3b0c44298fc",
  "ssl_protocol": "TLSv1.3",
  "ssl_cipher": "TLS_AES_256_GCM_SHA384"
}
```

Different clients will generate unique JA4 fingerprints, demonstrating the module's ability to distinguish between TLS implementations.

## ⚠️ Important Notes & Risks

### **Build Status**
- ❌ **Full ingress-controller integration**: Currently fails due to ModSecurity-Lua compatibility issues
- ✅ **Basic JA4 nginx module**: Successfully builds and functions correctly

### **Production Risk Assessment**
- 🔴 **HIGH RISK**: Beta software with known bugs that may produce incorrect JA4 values
- 🟡 **MEDIUM RISK**: Custom build required, maintenance burden, limited support
- 🟢 **LOW RISK**: Some JA4 variants return empty values in testing

### **Deployment Recommendations**
- ✅ **Recommended**: Development, testing, security research environments
- ❌ **Not Recommended**: Production, high-traffic, or compliance-sensitive deployments
- ⚠️ **Caution Required**: Extensive testing needed before any production consideration

### **Technical Limitations**
- This integration is based on **nginx-ingress-controller v1.11.5**
- JA4 module is currently in **beta** with known issues
- Monitor performance impact on SSL handshakes
- ModSecurity integration currently incompatible

## 🤝 Contributing

When contributing to this integration:
1. Test changes with the provided test scripts
2. Update documentation for any configuration changes
3. Ensure compatibility with existing ingress controller features

## 📄 License

This integration follows the same licensing as the original JA4 nginx module and nginx-ingress-controller.
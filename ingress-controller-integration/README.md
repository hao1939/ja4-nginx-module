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

### 2. Deploy to Kubernetes
```bash
# Deploy new ingress controller with JA4
./scripts/deploy.sh

# Or patch existing deployment
kubectl patch deployment ingress-nginx-controller -n ingress-nginx --patch-file kubernetes/deployment-patch.yaml
```

### 3. Test JA4 Functionality
```bash
./scripts/test-ja4.sh
```

## 📋 Prerequisites

- Docker for building the image
- Kubernetes cluster with nginx-ingress-controller
- `kubectl` configured for your cluster

## 🔧 Available JA4 Variables

| Variable | Description | Use Case |
|----------|-------------|----------|
| `$http_ssl_ja4` | Standard JA4 client fingerprint | Bot detection, client identification |
| `$http_ssl_ja4s` | Server JA4 fingerprint | Server configuration tracking |
| `$http_ssl_ja4h` | HTTP header fingerprint | User-Agent spoofing detection |
| `$http_ssl_ja4t` | TCP fingerprint | Network-level client identification |

## 📚 Documentation

- **[Integration Analysis](docs/INTEGRATION_ANALYSIS.md)** - Technical details and compatibility
- **[Usage Guide](docs/USAGE_GUIDE.md)** - Complete configuration examples  
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

## ⚠️ Important Notes

- This integration is based on **nginx-ingress-controller v1.11.5**
- JA4 module is currently in **beta** with known issues
- Test thoroughly before production deployment
- Monitor performance impact on SSL handshakes

## 🤝 Contributing

When contributing to this integration:
1. Test changes with the provided test scripts
2. Update documentation for any configuration changes
3. Ensure compatibility with existing ingress controller features

## 📄 License

This integration follows the same licensing as the original JA4 nginx module and nginx-ingress-controller.
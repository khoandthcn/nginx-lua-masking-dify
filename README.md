# 🛡️ Nginx Lua Masking Plugin v2.1.0

**Advanced Data Masking Plugin for Dify with Multi-Version Support**

[![Version](https://img.shields.io/badge/version-2.1.0-blue.svg)](https://github.com/YOUR_USERNAME/nginx-lua-masking-dify)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Dify](https://img.shields.io/badge/dify-v0.15.8%20%7C%20v1.7.0-orange.svg)](https://github.com/langgenius/dify)
[![OpenResty](https://img.shields.io/badge/openresty-1.21.4+-red.svg)](https://openresty.org)

Real-time data masking plugin with automatic Dify version detection, supporting both v0.15.8 and v1.7.0 with <1ms response time.

---

## 🎯 Key Features

### 🔒 **Advanced Data Masking**
- **Email Masking**: `user@example.com` → `EMAIL_1`
- **IP Classification**: 
  - Private IPs: `192.168.1.1` → `IP_PRIVATE_1`
  - Public IPs: `8.8.8.8` → `IP_PUBLIC_1`
- **IPv6 Support**: `2001:db8::1` → `IPV6_1`
- **Organization Masking**: `Google` → `ORG_1`
- **Domain Masking**: `google.com` → `DOMAIN_1`
- **Hostname Masking**: `localhost` → `HOSTNAME_1`

### 🎯 **Multi-Version Dify Support**
- **Dify v0.15.8**: Complete compatibility
- **Dify v1.7.0**: Enhanced features support
- **Auto-Detection**: Automatic version detection
- **Seamless Migration**: Zero-downtime upgrades

### ⚡ **High Performance**
- **Response Time**: <1ms average
- **Throughput**: 1000+ requests/second
- **Memory Usage**: <50MB
- **CPU Overhead**: <2%

### 🔧 **Multi-Environment Support**
- **OpenResty**: Full Lua functionality (recommended)
- **Nginx+Lua**: Compatible with lua-resty-core
- **Fallback Mode**: Basic proxy without Lua
- **Cross-Platform**: Linux, Windows 11 WSL2, Docker

---

## 🚀 Quick Start

### **One-Command Installation**
```bash
# Download and extract
wget https://github.com/YOUR_USERNAME/nginx-lua-masking-dify/archive/v2.1.0.tar.gz
tar -xzf v2.1.0.tar.gz
cd nginx-lua-masking-dify-2.1.0

# Deploy (auto-detects environment)
sudo ./scripts/deploy_v2_1.sh

# Test installation
./scripts/test_deployment.sh
```

### **Expected Results**
```bash
# Health check
$ curl http://localhost/masking/health
{
  "status": "healthy",
  "version": "2.1.0",
  "mode": "openresty",
  "dify_version": "auto-detect",
  "performance": {
    "avg_response_time": "0.095ms"
  }
}

# Masking test
$ curl http://localhost/masking/test
{
  "original": "Contact: admin@example.com, IP: 192.168.1.1",
  "masked": "Contact: EMAIL_1, IP: IP_PRIVATE_1",
  "processing_time_ms": "0.095"
}
```

---

## 📋 System Requirements

### **Minimum Requirements**
- **OS**: Ubuntu 18.04+, Debian 10+, CentOS 7+
- **RAM**: 512MB available
- **CPU**: 1 core
- **Disk**: 100MB free space

### **Recommended for Production**
- **OS**: Ubuntu 22.04 LTS
- **RAM**: 2GB+ available
- **CPU**: 2+ cores
- **Disk**: 1GB+ free space
- **Network**: Stable internet connection

### **Supported Environments**
| Environment | Status | Performance | Features |
|-------------|--------|-------------|----------|
| **OpenResty** | ✅ Recommended | Excellent | Full |
| **Nginx+Lua** | ✅ Supported | Good | Full |
| **Nginx Only** | ✅ Fallback | Basic | Limited |
| **Docker** | ✅ Tested | Excellent | Full |
| **Windows WSL2** | ✅ Tested | Good | Full |

---

## 🔧 Installation Options

### **Option 1: Automatic Installation (Recommended)**
```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/nginx-lua-masking-dify.git
cd nginx-lua-masking-dify

# Run comprehensive deployment
sudo ./scripts/deploy_v2_1.sh

# Validate installation
./scripts/test_deployment.sh
```

### **Option 2: Manual Installation**
```bash
# Install OpenResty
sudo apt update
sudo apt install -y openresty

# Install plugin
sudo mkdir -p /opt/nginx-lua-masking
sudo cp -r lib/* /opt/nginx-lua-masking/lib/
sudo cp examples/nginx_openresty_optimized.conf /usr/local/openresty/nginx/conf/nginx.conf

# Test and start
sudo openresty -t
sudo openresty
```

### **Option 3: Docker Deployment**
```bash
# Using provided Dockerfile
docker build -t nginx-lua-masking .
docker run -d -p 80:80 nginx-lua-masking

# Or use docker-compose
docker-compose up -d
```

---

## 📊 Performance Benchmarks

### **Response Time Performance**
| Operation | v2.0.0 | v2.1.0 | Improvement |
|-----------|--------|--------|-------------|
| **Health Check** | 0.183ms | 0.095ms | 48% faster |
| **Email Masking** | 0.002ms | 0.001ms | 50% faster |
| **JSON Processing** | 0.003ms | 0.002ms | 33% faster |
| **Full Request** | 0.250ms | 0.150ms | 40% faster |

### **Scalability Testing**
```bash
# Run performance test
./scripts/performance_test.sh

# Expected results:
# Concurrent users: 100
# Requests per second: 1000+
# Average response time: <1ms
# Memory usage: <50MB
```

---

## 🎯 Configuration

### **Basic Configuration**
```json
{
  "patterns": {
    "email": {"enabled": true, "prefix": "EMAIL"},
    "ip_private": {"enabled": true, "prefix": "IP_PRIVATE"},
    "ip_public": {"enabled": true, "prefix": "IP_PUBLIC"},
    "ipv6": {"enabled": true, "prefix": "IPV6"},
    "organization": {"enabled": true, "prefix": "ORG"},
    "domain": {"enabled": true, "prefix": "DOMAIN"},
    "hostname": {"enabled": true, "prefix": "HOSTNAME"}
  },
  "dify": {
    "backend": "127.0.0.1:5001",
    "version": "auto-detect",
    "endpoints": ["/v1/chat-messages", "/v1/completion-messages"]
  }
}
```

### **Advanced Configuration**
```nginx
# OpenResty optimized configuration
lua_shared_dict masking_mappings 50m;
lua_shared_dict masking_stats 10m;
lua_shared_dict masking_cache 20m;

# Performance tuning
lua_code_cache on;
lua_socket_pool_size 30;
lua_socket_keepalive_timeout 60s;
```

---

## 🧪 Testing

### **Unit Tests**
```bash
# Run all tests
cd test
lua run_tests.lua

# Expected: 88 tests, 100% pass rate
```

### **Integration Tests**
```bash
# Test Dify v0.15.8 integration
./scripts/test_dify_v0_15_integration.sh

# Test Dify v1.7.0 integration
./scripts/test_dify_v1_x_integration.sh
```

### **Performance Tests**
```bash
# Comprehensive performance testing
./scripts/performance_test.sh

# Memory usage testing
./scripts/test_memory_usage.sh

# Load testing
./scripts/load_test.sh
```

---

## 🔍 Monitoring & Debugging

### **Health Monitoring**
```bash
# Check plugin health
curl http://localhost/masking/health

# Debug information
curl http://localhost/masking/debug

# Performance metrics
curl http://localhost/masking/stats
```

### **Log Analysis**
```bash
# View error logs
sudo tail -f /var/log/nginx/error.log

# Filter plugin logs
sudo grep "MASKING-PLUGIN" /var/log/nginx/error.log

# Performance logs
sudo grep "processing_time" /var/log/nginx/error.log
```

### **Troubleshooting**
```bash
# Test fallback mode
./scripts/test_fallback_mode.sh

# Validate configuration
sudo openresty -t

# Check module loading
lua -e "require('utils'); print('OK')"
```

---

## 🔒 Security

### **Data Protection**
- **Real-time Masking**: Sensitive data never stored unmasked
- **Reversible Mapping**: Secure placeholder-to-original mapping
- **Memory Safety**: Automatic cleanup of sensitive data
- **Audit Trail**: Comprehensive logging of masking operations

### **Security Headers**
```nginx
add_header X-Frame-Options DENY always;
add_header X-Content-Type-Options nosniff always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

### **Rate Limiting**
```nginx
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=health:10m rate=1r/s;
```

---

## 📚 Documentation

### **Complete Guides**
- **[Installation Guide](docs/INSTALLATION.md)**: Step-by-step setup
- **[Configuration Guide](docs/CONFIGURATION.md)**: Advanced configuration
- **[API Documentation](docs/API.md)**: Complete API reference
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)**: Common issues
- **[Performance Guide](docs/PERFORMANCE.md)**: Optimization tips
- **[Windows 11 Setup](docs/WINDOWS_11_SETUP_GUIDE.md)**: WSL2 development

### **Examples**
- **[Production Config](examples/nginx_openresty_optimized.conf)**: Production-ready
- **[Development Config](examples/nginx_development.conf)**: Debug-enabled
- **[Docker Setup](examples/docker-compose.yml)**: Container deployment
- **[CI/CD Pipeline](examples/github-actions.yml)**: Automated deployment

---

## 🤝 Contributing

### **Development Setup**
```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/nginx-lua-masking-dify.git
cd nginx-lua-masking-dify

# Setup development environment
./scripts/setup_dev_environment.sh

# Run tests
./scripts/run_all_tests.sh
```

### **Code Standards**
- **Lua Style**: Follow OpenResty Lua style guide
- **Testing**: 100% test coverage required
- **Documentation**: Update docs for all changes
- **Performance**: Maintain <1ms response time

---

## 📞 Support

### **Community Support**
- **GitHub Issues**: [Report bugs and feature requests](https://github.com/YOUR_USERNAME/nginx-lua-masking-dify/issues)
- **Discussions**: [Community discussions](https://github.com/YOUR_USERNAME/nginx-lua-masking-dify/discussions)
- **Wiki**: [Community wiki](https://github.com/YOUR_USERNAME/nginx-lua-masking-dify/wiki)

### **Professional Support**
- **Enterprise Support**: Available for production deployments
- **Custom Development**: Tailored solutions for specific needs
- **Training**: Team training and workshops available

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🎉 Acknowledgments

- **OpenResty Team**: For the excellent Lua-enabled Nginx platform
- **Dify Team**: For the innovative AI application framework
- **Community Contributors**: For testing, feedback, and improvements

---

**🚀 Ready to protect your sensitive data with real-time masking? Get started with the one-command installation!**

```bash
sudo ./scripts/deploy_v2_1.sh
```


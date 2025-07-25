# Deployment Guide - Multi-Version Dify Support

Hướng dẫn triển khai Nginx Lua Masking Plugin v2.0.0 cho cả Dify v0.15.8 và v1.7.0

## 📋 Tổng Quan Deployment

### Deployment Options
1. **Single Version Deployment**: Triển khai cho một phiên bản Dify cụ thể
2. **Multi-Version Deployment**: Hỗ trợ đồng thời nhiều phiên bản Dify
3. **Blue-Green Deployment**: Triển khai không downtime
4. **Canary Deployment**: Triển khai từng phần để test

### Architecture Overview
```
┌─────────────────────────────────────────────────────────────┐
│                    Load Balancer                           │
│                   (nginx/haproxy)                          │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              Nginx Lua Masking Plugin                      │
│                     (v2.0.0)                               │
├─────────────────────────────────────────────────────────────┤
│  Auto Version Detection + Adapter Selection                │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        │                           │
┌───────▼────────┐         ┌────────▼────────┐
│  Dify v0.15.8  │         │  Dify v1.7.0    │
│   Backend      │         │   Backend       │
│                │         │                 │
│ • Basic APIs   │         │ • Enhanced APIs │
│ • Streaming    │         │ • OAuth         │
│ • Chat/Comp    │         │ • File Upload   │
└────────────────┘         └─────────────────┘
```

## 🚀 Pre-Deployment Checklist

### System Requirements
- [ ] **OS**: Ubuntu 22.04+ / CentOS 9+ / RHEL 9+
- [ ] **RAM**: 8GB minimum, 16GB recommended
- [ ] **CPU**: 4 cores minimum, 8 cores recommended
- [ ] **Disk**: 50GB available space
- [ ] **Network**: Stable internet connection

### Software Dependencies
- [ ] **OpenResty**: 1.21.4+ or Nginx 1.22+ with Lua modules
- [ ] **Lua**: 5.3+ with required libraries
- [ ] **Dify**: v0.15.8 or v1.7.0 running and accessible
- [ ] **Database**: PostgreSQL 15+ (for Dify)
- [ ] **Cache**: Redis 7.0+ (for Dify and plugin caching)

### Security Preparation
- [ ] **SSL Certificates**: Valid certificates for HTTPS
- [ ] **Firewall Rules**: Configured for required ports
- [ ] **API Keys**: Dify API keys ready
- [ ] **OAuth Setup**: OAuth credentials (for v1.7.0)
- [ ] **Backup Plan**: Data backup and recovery procedures

## 🔧 Installation Process

### Step 1: Download and Extract Plugin
```bash
# Download latest release
cd /opt
sudo wget https://github.com/your-repo/nginx-lua-masking-dify-v2.0.tar.gz
sudo tar -xzf nginx-lua-masking-dify-v2.0.tar.gz
sudo chown -R nginx:nginx nginx-lua-masking-dify-v2.0
cd nginx-lua-masking-dify-v2.0
```

### Step 2: Install Dependencies
```bash
# Install OpenResty (Ubuntu/Debian)
sudo apt update
sudo apt install openresty openresty-resty

# Install Lua dependencies
sudo luarocks install lua-resty-json
sudo luarocks install lua-resty-http
sudo luarocks install lua-resty-jwt  # For v1.7.0 OAuth
sudo luarocks install lua-resty-upload  # For v1.7.0 file upload

# Verify installation
openresty -v
lua -v
```

### Step 3: Detect Dify Version
```bash
# Auto-detect Dify version
./scripts/detect_dify_version.sh --url http://your-dify-backend:5001

# Manual version check
curl http://your-dify-backend:5001/v1/info
curl http://your-dify-backend:5001/health
```

### Step 4: Configure Plugin
```bash
# Copy appropriate configuration
if [ "$DIFY_VERSION" = "0.15.8" ]; then
    sudo cp config/versions/dify_v0_15_config.json /usr/local/openresty/conf/masking_config.json
    sudo cp examples/dify_v0_15_nginx.conf /usr/local/openresty/conf/nginx.conf
else
    sudo cp config/versions/dify_v1_x_config.json /usr/local/openresty/conf/masking_config.json
    sudo cp examples/dify_v1_x_nginx.conf /usr/local/openresty/conf/nginx.conf
fi

# Deploy plugin files
sudo cp -r lib/* /usr/local/openresty/lualib/
sudo chmod -R 755 /usr/local/openresty/lualib/
```

### Step 5: Customize Configuration
```bash
# Edit configuration for your environment
sudo nano /usr/local/openresty/conf/masking_config.json

# Update Nginx configuration
sudo nano /usr/local/openresty/conf/nginx.conf

# Key configurations to update:
# - Backend upstream servers
# - Domain names
# - SSL certificates
# - OAuth credentials (v1.7.0)
# - File upload settings (v1.7.0)
```

## 🔧 Configuration Templates

### Basic Configuration (Both Versions)
```json
{
  "version": "auto-detect",
  "masking": {
    "enabled": true,
    "patterns": {
      "email": {
        "enabled": true,
        "placeholder_prefix": "EMAIL"
      },
      "ip_private": {
        "enabled": true,
        "placeholder_prefix": "IP_PRIVATE"
      },
      "ip_public": {
        "enabled": true,
        "placeholder_prefix": "IP_PUBLIC"
      }
    }
  },
  "performance": {
    "cache_mappings": true,
    "cache_ttl": 3600,
    "max_cache_size": 50000
  }
}
```

### Enhanced Configuration (v1.7.0 Only)
```json
{
  "version": "1.7.0",
  "oauth": {
    "enabled": true,
    "client_id": "${OAUTH_CLIENT_ID}",
    "client_secret": "${OAUTH_CLIENT_SECRET}",
    "token_endpoint": "/oauth/token"
  },
  "file_upload": {
    "enabled": true,
    "max_file_size": 100000000,
    "allowed_types": ["image/jpeg", "image/png", "application/pdf"]
  },
  "external_trace": {
    "enabled": true,
    "generate_if_missing": true
  }
}
```

### Nginx Configuration Template
```nginx
# /usr/local/openresty/conf/nginx.conf

worker_processes auto;
error_log /var/log/nginx/error.log info;

events {
    worker_connections 2048;
    use epoll;
    multi_accept on;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    
    # Lua configuration
    lua_package_path "/usr/local/openresty/lualib/?.lua;;";
    lua_shared_dict masking_cache 50m;
    lua_shared_dict mapping_store 100m;
    
    # Initialize plugin
    init_by_lua_block {
        local utils = require("utils")
        local config = utils.load_json_file("/usr/local/openresty/conf/masking_config.json")
        ngx.shared.masking_cache:set("config", utils.json.encode(config))
    }
    
    # Upstream configuration
    upstream dify_backend {
        server 127.0.0.1:5001 max_fails=3 fail_timeout=30s;
        keepalive 64;
    }
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    
    server {
        listen 80;
        listen 443 ssl http2;
        server_name your-domain.com;
        
        # SSL configuration
        ssl_certificate /path/to/cert.pem;
        ssl_certificate_key /path/to/key.pem;
        
        # Health check
        location /masking/health {
            content_by_lua_block {
                local utils = require("utils")
                local version_detector = require("version_detector")
                
                local health = {
                    status = "healthy",
                    version = "2.0.0",
                    timestamp = ngx.time()
                }
                
                ngx.header.content_type = "application/json"
                ngx.say(utils.json.encode(health))
            }
        }
        
        # Main API endpoints
        location ~ ^/v1/ {
            limit_req zone=api burst=10 nodelay;
            
            access_by_lua_block {
                local version_detector = require("version_detector")
                local adapter_factory = require("adapters.adapter_factory")
                local utils = require("utils")
                
                -- Load configuration
                local config_json = ngx.shared.masking_cache:get("config")
                local config = utils.json.decode(config_json)
                
                -- Detect version and create adapter
                local detector = version_detector.new()
                local context = {
                    headers = ngx.req.get_headers(),
                    request_uri = ngx.var.request_uri
                }
                
                detector:detect_version(context)
                local adapter = adapter_factory.create_adapter_with_detection(detector, config)
                
                if adapter then
                    -- Process request
                    ngx.req.read_body()
                    local body = ngx.req.get_body_data()
                    local processed_body = adapter:process_request(ngx.var.request_uri, ngx.req.get_method(), body, ngx.req.get_headers())
                    
                    if processed_body and processed_body ~= body then
                        ngx.req.set_body_data(processed_body)
                    end
                    
                    ngx.ctx.adapter = adapter
                end
            }
            
            # Proxy to Dify
            proxy_pass http://dify_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Handle streaming
            proxy_buffering off;
            proxy_cache off;
            
            # Process response
            body_filter_by_lua_block {
                local adapter = ngx.ctx.adapter
                if adapter then
                    local chunk = ngx.arg[1]
                    if chunk then
                        local processed_chunk = adapter:process_response(ngx.var.request_uri, ngx.req.get_method(), chunk, ngx.header)
                        if processed_chunk then
                            ngx.arg[1] = processed_chunk
                        end
                    end
                end
            }
        }
        
        # Proxy other requests
        location / {
            proxy_pass http://dify_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```

## 🚀 Deployment Strategies

### Strategy 1: Single Version Deployment

#### For Dify v0.15.8
```bash
# 1. Prepare environment
export DIFY_VERSION="0.15.8"
export DIFY_BACKEND="127.0.0.1:5001"
export DOMAIN="your-domain.com"

# 2. Deploy configuration
sudo cp config/versions/dify_v0_15_config.json /usr/local/openresty/conf/masking_config.json

# 3. Deploy Nginx config
envsubst < examples/dify_v0_15_nginx.conf | sudo tee /usr/local/openresty/conf/nginx.conf

# 4. Test configuration
sudo nginx -t

# 5. Start services
sudo systemctl start openresty
sudo systemctl enable openresty
```

#### For Dify v1.7.0
```bash
# 1. Prepare environment with enhanced features
export DIFY_VERSION="1.7.0"
export DIFY_BACKEND="127.0.0.1:5001"
export DOMAIN="your-domain.com"
export OAUTH_CLIENT_ID="your_oauth_client_id"
export OAUTH_CLIENT_SECRET="your_oauth_client_secret"

# 2. Deploy enhanced configuration
sudo cp config/versions/dify_v1_x_config.json /usr/local/openresty/conf/masking_config.json

# 3. Update OAuth credentials
sudo sed -i "s/\${OAUTH_CLIENT_ID}/$OAUTH_CLIENT_ID/g" /usr/local/openresty/conf/masking_config.json
sudo sed -i "s/\${OAUTH_CLIENT_SECRET}/$OAUTH_CLIENT_SECRET/g" /usr/local/openresty/conf/masking_config.json

# 4. Deploy enhanced Nginx config
envsubst < examples/dify_v1_x_nginx.conf | sudo tee /usr/local/openresty/conf/nginx.conf

# 5. Test and start
sudo nginx -t
sudo systemctl start openresty
sudo systemctl enable openresty
```

### Strategy 2: Multi-Version Deployment
```bash
# 1. Deploy with auto-detection
sudo cp config/multi_version_config.json /usr/local/openresty/conf/masking_config.json

# 2. Use adaptive Nginx configuration
sudo cp examples/adaptive_nginx.conf /usr/local/openresty/conf/nginx.conf

# 3. Configure multiple upstreams
cat >> /usr/local/openresty/conf/nginx.conf << EOF
upstream dify_v015 {
    server 127.0.0.1:5001;
}

upstream dify_v1x {
    server 127.0.0.1:5002;
}
EOF

# 4. Start with load balancing
sudo systemctl start openresty
```

### Strategy 3: Blue-Green Deployment
```bash
# 1. Prepare blue environment (current)
sudo cp /usr/local/openresty/conf/nginx.conf /usr/local/openresty/conf/nginx.conf.blue

# 2. Prepare green environment (new)
sudo cp examples/dify_v1_x_nginx.conf /usr/local/openresty/conf/nginx.conf.green

# 3. Test green environment
sudo nginx -t -c /usr/local/openresty/conf/nginx.conf.green

# 4. Switch to green (zero downtime)
sudo mv /usr/local/openresty/conf/nginx.conf.green /usr/local/openresty/conf/nginx.conf
sudo nginx -s reload

# 5. Verify and cleanup
curl http://your-domain.com/masking/health
sudo rm /usr/local/openresty/conf/nginx.conf.blue
```

### Strategy 4: Canary Deployment
```bash
# 1. Deploy canary configuration (10% traffic to new version)
cat > /usr/local/openresty/conf/canary.conf << EOF
upstream dify_stable {
    server 127.0.0.1:5001 weight=9;
}

upstream dify_canary {
    server 127.0.0.1:5002 weight=1;
}

upstream dify_backend {
    server 127.0.0.1:5001 weight=9;
    server 127.0.0.1:5002 weight=1;
}
EOF

# 2. Monitor canary metrics
watch -n 5 'curl -s http://your-domain.com/masking/stats | jq .performance'

# 3. Gradually increase canary traffic
# Update weights: 8:2, 7:3, 5:5, 3:7, 1:9, 0:10

# 4. Complete rollout
sudo systemctl reload openresty
```

## 📊 Post-Deployment Validation

### Health Checks
```bash
# 1. Basic health check
curl http://your-domain.com/masking/health
# Expected: {"status": "healthy", "version": "2.0.0"}

# 2. Version detection check
curl -H "X-Dify-Version: 1.7.0" http://your-domain.com/masking/health
# Expected: Correct version detection

# 3. API functionality check
curl -X POST http://your-domain.com/v1/chat-messages \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"query": "Test email user@example.com", "user": "test"}'
# Expected: Successful response with masked data

# 4. Performance check
curl http://your-domain.com/masking/stats
# Expected: Performance metrics within acceptable ranges
```

### Functional Testing
```bash
# 1. Test masking patterns
./scripts/test_masking_patterns.sh

# 2. Test version-specific features
if [ "$DIFY_VERSION" = "1.7.0" ]; then
    # Test OAuth
    curl http://your-domain.com/oauth/authorize
    
    # Test file upload
    curl -X POST http://your-domain.com/v1/files/upload \
      -H "Authorization: Bearer your-api-key" \
      -F "file=@test.txt"
fi

# 3. Test streaming responses
curl -N -H "Accept: text/event-stream" \
  -X POST http://your-domain.com/v1/chat-messages \
  -H "Authorization: Bearer your-api-key" \
  -d '{"query": "Stream test", "response_mode": "streaming"}'
```

### Performance Testing
```bash
# 1. Load testing with Apache Bench
ab -n 1000 -c 10 -H "Authorization: Bearer your-api-key" \
  -p test_payload.json -T application/json \
  http://your-domain.com/v1/chat-messages

# 2. Stress testing with wrk
wrk -t12 -c400 -d30s --script=test_script.lua \
  http://your-domain.com/v1/chat-messages

# 3. Monitor resource usage
htop
iostat -x 1
```

## 🔧 Configuration Management

### Environment-Specific Configs
```bash
# Development
sudo cp config/environments/development.json /usr/local/openresty/conf/masking_config.json

# Staging
sudo cp config/environments/staging.json /usr/local/openresty/conf/masking_config.json

# Production
sudo cp config/environments/production.json /usr/local/openresty/conf/masking_config.json
```

### Configuration Validation
```bash
# Validate configuration syntax
lua -e "
local utils = require('utils')
local config = utils.load_json_file('/usr/local/openresty/conf/masking_config.json')
print('Configuration is valid')
"

# Test configuration with plugin
lua test/validate_config.lua /usr/local/openresty/conf/masking_config.json
```

### Hot Configuration Reload
```bash
# Reload configuration without restart
sudo nginx -s reload

# Verify new configuration is active
curl http://your-domain.com/masking/config
```

## 📊 Monitoring Setup

### Log Configuration
```nginx
# Enhanced logging
log_format masking_log '$remote_addr - $remote_user [$time_local] '
                      '"$request" $status $body_bytes_sent '
                      '"$http_referer" "$http_user_agent" '
                      'dify_version="$dify_version" '
                      'masking_time="$masking_time" '
                      'patterns_matched="$patterns_matched"';

access_log /var/log/nginx/masking_access.log masking_log;
error_log /var/log/nginx/masking_error.log info;
```

### Metrics Collection
```bash
# Install monitoring tools
sudo apt install prometheus-node-exporter
sudo systemctl start prometheus-node-exporter

# Configure Nginx metrics
sudo cp config/nginx_prometheus.conf /usr/local/openresty/conf/conf.d/
```

### Alerting Rules
```yaml
# prometheus_alerts.yml
groups:
  - name: nginx_masking_plugin
    rules:
      - alert: HighErrorRate
        expr: rate(nginx_http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          
      - alert: SlowResponseTime
        expr: histogram_quantile(0.95, rate(nginx_http_request_duration_seconds_bucket[5m])) > 0.005
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Slow response time detected"
```

## 🔒 Security Hardening

### SSL/TLS Configuration
```nginx
# Strong SSL configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;

# HSTS
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

# Security headers
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
```

### Access Control
```nginx
# IP whitelist for admin endpoints
location /masking/admin {
    allow 10.0.0.0/8;
    allow 172.16.0.0/12;
    allow 192.168.0.0/16;
    deny all;
    
    # Admin functionality
}

# Rate limiting for API endpoints
limit_req_zone $binary_remote_addr zone=strict:10m rate=1r/s;
location /v1/ {
    limit_req zone=strict burst=5 nodelay;
}
```

### Data Protection
```bash
# Encrypt configuration files
sudo gpg --cipher-algo AES256 --compress-algo 1 --s2k-cipher-algo AES256 \
  --s2k-digest-algo SHA512 --s2k-mode 3 --s2k-count 65536 \
  --symmetric /usr/local/openresty/conf/masking_config.json

# Set secure file permissions
sudo chmod 600 /usr/local/openresty/conf/masking_config.json
sudo chown nginx:nginx /usr/local/openresty/conf/masking_config.json
```

## 🔄 Backup and Recovery

### Configuration Backup
```bash
# Create backup script
cat > /usr/local/bin/backup_masking_config.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/masking-plugin/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup configurations
cp -r /usr/local/openresty/conf/ "$BACKUP_DIR/conf/"
cp -r /usr/local/openresty/lualib/ "$BACKUP_DIR/lualib/"

# Create archive
tar -czf "$BACKUP_DIR.tar.gz" -C /backup/masking-plugin "$(basename $BACKUP_DIR)"
rm -rf "$BACKUP_DIR"

echo "Backup created: $BACKUP_DIR.tar.gz"
EOF

sudo chmod +x /usr/local/bin/backup_masking_config.sh

# Schedule daily backups
echo "0 2 * * * /usr/local/bin/backup_masking_config.sh" | sudo crontab -
```

### Disaster Recovery
```bash
# Recovery script
cat > /usr/local/bin/restore_masking_config.sh << 'EOF'
#!/bin/bash
BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file.tar.gz>"
    exit 1
fi

# Stop services
sudo systemctl stop openresty

# Restore from backup
sudo tar -xzf "$BACKUP_FILE" -C /
sudo chown -R nginx:nginx /usr/local/openresty/

# Validate and restart
sudo nginx -t && sudo systemctl start openresty

echo "Recovery completed from: $BACKUP_FILE"
EOF

sudo chmod +x /usr/local/bin/restore_masking_config.sh
```

## 🚀 Scaling and Optimization

### Horizontal Scaling
```bash
# Load balancer configuration
upstream masking_cluster {
    server masking-node1.example.com:80 weight=3;
    server masking-node2.example.com:80 weight=3;
    server masking-node3.example.com:80 weight=2;
    
    # Health checks
    check interval=3000 rise=2 fall=3 timeout=1000;
}
```

### Performance Optimization
```nginx
# Worker optimization
worker_processes auto;
worker_rlimit_nofile 65535;
worker_connections 4096;

# Caching optimization
lua_shared_dict masking_cache 200m;
lua_shared_dict mapping_store 500m;

# Connection optimization
upstream dify_backend {
    server 127.0.0.1:5001;
    keepalive 128;
    keepalive_requests 1000;
    keepalive_timeout 60s;
}
```

### Memory Management
```lua
-- Memory optimization in Lua code
local function cleanup_old_mappings()
    local mapping_store = ngx.shared.mapping_store
    local current_time = ngx.time()
    
    -- Clean mappings older than 1 hour
    for key, _ in pairs(mapping_store:get_keys()) do
        local timestamp = mapping_store:get(key .. "_timestamp")
        if timestamp and (current_time - timestamp) > 3600 then
            mapping_store:delete(key)
            mapping_store:delete(key .. "_timestamp")
        end
    end
end

-- Schedule cleanup every 10 minutes
ngx.timer.every(600, cleanup_old_mappings)
```

## 📋 Maintenance Procedures

### Regular Maintenance Tasks
```bash
# Weekly maintenance script
cat > /usr/local/bin/weekly_maintenance.sh << 'EOF'
#!/bin/bash

# 1. Log rotation
sudo logrotate -f /etc/logrotate.d/nginx

# 2. Cache cleanup
sudo find /var/cache/nginx -type f -mtime +7 -delete

# 3. Performance check
curl -s http://localhost/masking/stats | jq .performance

# 4. Configuration validation
sudo nginx -t

# 5. Security updates
sudo apt update && sudo apt upgrade -y openresty

echo "Weekly maintenance completed: $(date)"
EOF

sudo chmod +x /usr/local/bin/weekly_maintenance.sh

# Schedule weekly maintenance
echo "0 3 * * 0 /usr/local/bin/weekly_maintenance.sh" | sudo crontab -
```

### Update Procedures
```bash
# Plugin update script
cat > /usr/local/bin/update_masking_plugin.sh << 'EOF'
#!/bin/bash
NEW_VERSION="$1"

if [ -z "$NEW_VERSION" ]; then
    echo "Usage: $0 <new_version>"
    exit 1
fi

# 1. Backup current version
/usr/local/bin/backup_masking_config.sh

# 2. Download new version
cd /tmp
wget "https://github.com/your-repo/nginx-lua-masking-dify-v${NEW_VERSION}.tar.gz"

# 3. Test new version
tar -xzf "nginx-lua-masking-dify-v${NEW_VERSION}.tar.gz"
cd "nginx-lua-masking-dify-v${NEW_VERSION}"
lua test/run_multi_version_tests.lua

# 4. Deploy if tests pass
if [ $? -eq 0 ]; then
    sudo systemctl stop openresty
    sudo cp -r lib/* /usr/local/openresty/lualib/
    sudo nginx -t && sudo systemctl start openresty
    echo "Update to v${NEW_VERSION} completed successfully"
else
    echo "Tests failed, update aborted"
    exit 1
fi
EOF

sudo chmod +x /usr/local/bin/update_masking_plugin.sh
```

## 🆘 Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: Plugin Not Loading
```bash
# Check Lua path
nginx -T | grep lua_package_path

# Verify file permissions
ls -la /usr/local/openresty/lualib/

# Test module loading
lua -e "require('utils'); print('OK')"
```

#### Issue 2: Version Detection Failing
```bash
# Check Dify backend connectivity
curl -v http://127.0.0.1:5001/health

# Test version detection manually
lua -e "
local detector = require('version_detector')
local d = detector.new()
local version = d:detect_version({headers = {['x-dify-version'] = '1.7.0'}})
print('Detected:', version)
"
```

#### Issue 3: Performance Issues
```bash
# Check resource usage
htop
iostat -x 1

# Monitor Nginx processes
ps aux | grep nginx

# Check cache hit rates
curl http://localhost/masking/stats | jq .cache
```

#### Issue 4: SSL/TLS Issues
```bash
# Test SSL configuration
openssl s_client -connect your-domain.com:443 -servername your-domain.com

# Check certificate validity
openssl x509 -in /path/to/cert.pem -text -noout

# Verify SSL configuration
nginx -T | grep ssl
```

### Emergency Procedures

#### Rollback to Previous Version
```bash
# 1. Stop current version
sudo systemctl stop openresty

# 2. Restore from backup
sudo /usr/local/bin/restore_masking_config.sh /backup/masking-plugin/latest.tar.gz

# 3. Verify and start
sudo nginx -t && sudo systemctl start openresty
```

#### Disable Plugin (Emergency)
```bash
# 1. Create bypass configuration
cat > /tmp/bypass.conf << 'EOF'
location / {
    proxy_pass http://dify_backend;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
EOF

# 2. Replace main configuration
sudo cp /tmp/bypass.conf /usr/local/openresty/conf/nginx.conf

# 3. Reload immediately
sudo nginx -s reload
```

## 📞 Support and Escalation

### Support Levels
1. **Level 1**: Basic configuration and setup issues
2. **Level 2**: Performance optimization and troubleshooting
3. **Level 3**: Advanced debugging and custom development

### Escalation Procedures
1. **Gather Information**: Logs, configuration, error messages
2. **Document Issue**: Clear description with reproduction steps
3. **Contact Support**: Use appropriate channel based on severity
4. **Follow Up**: Provide additional information as requested

### Emergency Contacts
- **Critical Issues**: emergency@your-company.com
- **General Support**: support@your-company.com
- **Community**: GitHub Issues and Discussions

---

**Deployment Guide v2.0.0**  
**Last Updated**: 2025-07-25  
**Next Review**: 2025-10-25


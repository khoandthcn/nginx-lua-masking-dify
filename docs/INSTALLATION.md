# Installation Guide - Nginx Lua Masking Plugin

## System Requirements

### Minimum Requirements
- **OS**: Linux (Ubuntu 18.04+, CentOS 7+, RHEL 7+)
- **Nginx**: 1.14+ with lua-resty-core
- **Lua**: 5.1/5.2/5.3 hoặc LuaJIT 2.0+
- **Memory**: 512MB RAM minimum
- **Disk**: 100MB free space

### Recommended Requirements
- **OS**: Ubuntu 20.04+ hoặc CentOS 8+
- **Nginx**: 1.18+ with OpenResty
- **Lua**: LuaJIT 2.1+
- **Memory**: 2GB+ RAM
- **Disk**: 1GB+ free space

## Installation Methods

### Method 1: OpenResty (Recommended)

OpenResty là cách dễ nhất để cài đặt plugin.

#### 1. Install OpenResty

**Ubuntu/Debian:**
```bash
# Add OpenResty repository
wget -qO - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list

# Install OpenResty
sudo apt update
sudo apt install openresty
```

**CentOS/RHEL:**
```bash
# Add OpenResty repository
sudo yum install yum-utils
sudo yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo

# Install OpenResty
sudo yum install openresty
```

#### 2. Install Plugin

```bash
# Download plugin
git clone <repository-url> nginx-lua-masking
cd nginx-lua-masking

# Copy files to OpenResty
sudo cp -r lib/ /usr/local/openresty/lualib/
sudo cp -r config/ /usr/local/openresty/lualib/

# Set permissions
sudo chown -R root:root /usr/local/openresty/lualib/lib/
sudo chown -R root:root /usr/local/openresty/lualib/config/
sudo chmod -R 644 /usr/local/openresty/lualib/lib/*.lua
sudo chmod -R 644 /usr/local/openresty/lualib/config/*.json
```

#### 3. Configure OpenResty

```bash
# Edit nginx configuration
sudo vim /usr/local/openresty/nginx/conf/nginx.conf
```

Add plugin configuration:
```nginx
http {
    # Lua package path
    lua_package_path "/usr/local/openresty/lualib/?.lua;;";
    
    # Initialize plugin
    init_by_lua_block {
        local masking_plugin = require("masking_plugin")
        _G.masking_plugin = masking_plugin
    }
    
    # Your server configuration
    server {
        listen 80;
        server_name example.com;
        
        location /api/ {
            # Plugin integration (see Configuration section)
            proxy_pass http://backend;
        }
    }
}
```

#### 4. Start OpenResty

```bash
# Test configuration
sudo /usr/local/openresty/bin/openresty -t

# Start OpenResty
sudo systemctl start openresty
sudo systemctl enable openresty
```

### Method 2: Nginx with lua-resty-core

Nếu bạn đã có Nginx installation, có thể add lua support.

#### 1. Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install nginx-extras lua5.3 liblua5.3-dev
```

**CentOS/RHEL:**
```bash
sudo yum install epel-release
sudo yum install nginx lua lua-devel
```

#### 2. Install lua-resty-core

```bash
# Download lua-resty-core
wget https://github.com/openresty/lua-resty-core/archive/v0.1.21.tar.gz
tar -xzf v0.1.21.tar.gz
cd lua-resty-core-0.1.21

# Install
sudo make install PREFIX=/usr/local
```

#### 3. Install Plugin

```bash
# Create directories
sudo mkdir -p /usr/local/nginx/lua/lib
sudo mkdir -p /usr/local/nginx/lua/config

# Copy plugin files
sudo cp -r lib/* /usr/local/nginx/lua/lib/
sudo cp -r config/* /usr/local/nginx/lua/config/

# Set permissions
sudo chown -R nginx:nginx /usr/local/nginx/lua/
sudo chmod -R 644 /usr/local/nginx/lua/lib/*.lua
sudo chmod -R 644 /usr/local/nginx/lua/config/*.json
```

#### 4. Configure Nginx

Edit `/etc/nginx/nginx.conf`:

```nginx
# Load lua module (if not already loaded)
load_module modules/ngx_http_lua_module.so;

http {
    # Lua package path
    lua_package_path "/usr/local/nginx/lua/?.lua;;";
    
    # Initialize plugin
    init_by_lua_block {
        local masking_plugin = require("masking_plugin")
        _G.masking_plugin = masking_plugin
    }
    
    # Rest of configuration...
}
```

### Method 3: Docker Installation

Sử dụng Docker để deploy plugin.

#### 1. Create Dockerfile

```dockerfile
FROM openresty/openresty:alpine

# Copy plugin files
COPY lib/ /usr/local/openresty/lualib/lib/
COPY config/ /usr/local/openresty/lualib/config/
COPY examples/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# Set permissions
RUN chown -R nobody:nobody /usr/local/openresty/lualib/ && \
    chmod -R 644 /usr/local/openresty/lualib/lib/*.lua && \
    chmod -R 644 /usr/local/openresty/lualib/config/*.json

EXPOSE 80

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
```

#### 2. Build and Run

```bash
# Build image
docker build -t nginx-lua-masking .

# Run container
docker run -d -p 80:80 --name masking-proxy nginx-lua-masking
```

#### 3. Docker Compose

```yaml
version: '3.8'

services:
  nginx-masking:
    build: .
    ports:
      - "80:80"
    volumes:
      - ./config:/usr/local/openresty/lualib/config
      - ./logs:/usr/local/openresty/nginx/logs
    environment:
      - NGINX_WORKER_PROCESSES=auto
    restart: unless-stopped
    
  backend:
    image: your-backend-image
    ports:
      - "8080:8080"
```

## Configuration

### Basic Configuration

Tạo file cấu hình `/usr/local/openresty/lualib/config/masking.json`:

```json
{
    "enabled": true,
    "debug": false,
    "log_level": "INFO",
    
    "patterns": {
        "email": {
            "enabled": true,
            "regex": "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z][a-zA-Z]+",
            "placeholder_prefix": "EMAIL"
        },
        "ipv4": {
            "enabled": true,
            "regex": "\\d+\\.\\d+\\.\\d+\\.\\d+",
            "placeholder_prefix": "IP"
        },
        "organizations": {
            "enabled": true,
            "static_list": ["Google", "Microsoft", "Amazon", "Facebook", "Apple"],
            "placeholder_prefix": "ORG"
        }
    },
    
    "json_paths": [
        "$.user.email",
        "$.server.ip",
        "$.company.name"
    ]
}
```

### Nginx Integration

Add plugin vào Nginx configuration:

```nginx
http {
    lua_package_path "/usr/local/openresty/lualib/?.lua;;";
    
    # Load configuration
    init_by_lua_block {
        local masking_plugin = require("masking_plugin")
        local config_file = "/usr/local/openresty/lualib/config/masking.json"
        
        -- Load config from file
        local file = io.open(config_file, "r")
        if file then
            local config_json = file:read("*all")
            file:close()
            
            local cjson = require("cjson")
            local config = cjson.decode(config_json)
            
            _G.masking_plugin_instance = masking_plugin.new(config)
        else
            _G.masking_plugin_instance = masking_plugin.new()
        end
    }
    
    server {
        listen 80;
        server_name your-domain.com;
        
        # API endpoint with masking
        location /api/ {
            # Process request
            access_by_lua_block {
                local plugin = _G.masking_plugin_instance
                
                -- Read request body
                ngx.req.read_body()
                local body = ngx.req.get_body_data()
                
                if body then
                    local content_type = ngx.req.get_headers()["content-type"]
                    local headers = ngx.req.get_headers()
                    
                    local masked_body, modified = plugin:process_request(body, content_type, headers)
                    
                    if modified then
                        ngx.req.set_body_data(masked_body)
                        ngx.log(ngx.INFO, "Request masked successfully")
                    end
                end
            }
            
            # Process response
            body_filter_by_lua_block {
                local plugin = _G.masking_plugin_instance
                
                local chunk = ngx.arg[1]
                local eof = ngx.arg[2]
                
                if chunk and chunk ~= "" then
                    local content_type = ngx.header.content_type
                    local unmasked_chunk = plugin:process_response_chunk(chunk, content_type, eof)
                    ngx.arg[1] = unmasked_chunk
                end
            }
            
            # Proxy to backend
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        
        # Health check endpoint
        location /health {
            access_by_lua_block {
                local plugin = _G.masking_plugin_instance
                local health = plugin:health_check()
                
                ngx.header.content_type = "application/json"
                ngx.say(require("cjson").encode(health))
                ngx.exit(200)
            }
        }
        
        # Statistics endpoint
        location /stats {
            access_by_lua_block {
                local plugin = _G.masking_plugin_instance
                local stats = plugin:get_stats()
                
                ngx.header.content_type = "application/json"
                ngx.say(require("cjson").encode(stats))
                ngx.exit(200)
            }
        }
    }
    
    # Backend upstream
    upstream backend {
        server 127.0.0.1:8080;
        keepalive 32;
    }
}
```

## Testing Installation

### 1. Test Plugin Loading

```bash
# Test nginx configuration
sudo nginx -t

# Check if plugin loads correctly
curl -X POST http://localhost/api/test \
  -H "Content-Type: application/json" \
  -d '{"user": {"email": "test@example.com"}}'
```

### 2. Test Masking Functionality

```bash
# Send request with sensitive data
curl -X POST http://localhost/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "john@example.com",
      "server_ip": "192.168.1.100"
    },
    "company": {
      "name": "Google"
    }
  }'

# Check logs to verify masking
sudo tail -f /var/log/nginx/access.log
```

### 3. Test Health Check

```bash
# Check plugin health
curl http://localhost/health

# Expected response:
# {
#   "status": "healthy",
#   "timestamp": 1721826450,
#   "stats": {...}
# }
```

### 4. Test Statistics

```bash
# Get plugin statistics
curl http://localhost/stats

# Expected response:
# {
#   "plugin": {
#     "total_requests": 10,
#     "successful_requests": 10,
#     "error_count": 0
#   },
#   "patterns": {
#     "total_mappings": 5
#   }
# }
```

## Performance Tuning

### 1. Nginx Configuration

```nginx
# Optimize worker processes
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    # Lua settings
    lua_code_cache on;
    lua_max_running_timers 256;
    lua_max_pending_timers 1024;
    
    # Shared dictionaries for caching
    lua_shared_dict masking_cache 10m;
    lua_shared_dict masking_stats 1m;
    
    # Buffer sizes
    client_body_buffer_size 128k;
    client_max_body_size 10m;
    
    # Proxy settings
    proxy_buffering on;
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;
}
```

### 2. Plugin Configuration

```json
{
    "performance": {
        "max_mappings": 10000,
        "cleanup_interval": 3600,
        "memory_limit": "100MB",
        "cache_enabled": true,
        "cache_ttl": 300
    }
}
```

### 3. System Optimization

```bash
# Increase file descriptor limits
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

# Optimize kernel parameters
echo "net.core.somaxconn = 65535" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 65535" >> /etc/sysctl.conf
sysctl -p
```

## Monitoring and Logging

### 1. Log Configuration

```nginx
# Custom log format
log_format masking '$remote_addr - $remote_user [$time_local] '
                  '"$request" $status $body_bytes_sent '
                  '"$http_referer" "$http_user_agent" '
                  'masked=$masking_modified rt=$request_time';

access_log /var/log/nginx/masking.log masking;
error_log /var/log/nginx/error.log info;
```

### 2. Metrics Collection

```lua
-- In init_by_lua_block
local prometheus = require("resty.prometheus")
local metrics = prometheus.init("prometheus_metrics")

_G.masking_metrics = {
    requests = metrics:counter("masking_requests_total", "Total requests processed"),
    errors = metrics:counter("masking_errors_total", "Total errors"),
    processing_time = metrics:histogram("masking_processing_seconds", "Processing time")
}
```

### 3. Health Monitoring

```bash
# Create monitoring script
cat > /usr/local/bin/check_masking.sh << 'EOF'
#!/bin/bash

HEALTH_URL="http://localhost/health"
RESPONSE=$(curl -s $HEALTH_URL)
STATUS=$(echo $RESPONSE | jq -r '.status')

if [ "$STATUS" != "healthy" ]; then
    echo "CRITICAL: Masking plugin is not healthy"
    exit 2
fi

echo "OK: Masking plugin is healthy"
exit 0
EOF

chmod +x /usr/local/bin/check_masking.sh

# Add to crontab for monitoring
echo "*/5 * * * * /usr/local/bin/check_masking.sh" | crontab -
```

## Troubleshooting

### Common Issues

#### 1. Module Not Found

**Error:**
```
lua entry thread aborted: runtime error: module 'masking_plugin' not found
```

**Solution:**
```bash
# Check lua_package_path
nginx -T | grep lua_package_path

# Verify file exists
ls -la /usr/local/openresty/lualib/masking_plugin.lua

# Fix path if needed
lua_package_path "/usr/local/openresty/lualib/?.lua;;";
```

#### 2. Permission Denied

**Error:**
```
failed to load external Lua file: permission denied
```

**Solution:**
```bash
# Fix permissions
sudo chown -R nginx:nginx /usr/local/openresty/lualib/
sudo chmod -R 644 /usr/local/openresty/lualib/*.lua
```

#### 3. JSON Parsing Error

**Error:**
```
Expected value but found invalid token at character 1
```

**Solution:**
```bash
# Check JSON syntax
python -m json.tool /usr/local/openresty/lualib/config/masking.json

# Fix JSON format
vim /usr/local/openresty/lualib/config/masking.json
```

#### 4. Memory Issues

**Error:**
```
not enough memory
```

**Solution:**
```nginx
# Increase shared dictionary size
lua_shared_dict masking_cache 50m;

# Or in plugin config
{
    "performance": {
        "memory_limit": "200MB",
        "cleanup_interval": 1800
    }
}
```

### Debug Mode

Enable debug mode để troubleshoot:

```json
{
    "debug": true,
    "log_level": "DEBUG"
}
```

```nginx
# Enable debug logging
error_log /var/log/nginx/debug.log debug;
```

### Log Analysis

```bash
# Check masking activity
grep "MASKING-PLUGIN" /var/log/nginx/error.log

# Monitor performance
tail -f /var/log/nginx/masking.log | grep "rt="

# Check error patterns
grep "ERROR" /var/log/nginx/error.log | tail -20
```

## Uninstallation

### Remove Plugin Files

```bash
# Remove plugin files
sudo rm -rf /usr/local/openresty/lualib/lib/
sudo rm -rf /usr/local/openresty/lualib/config/

# Remove configuration
sudo rm /usr/local/openresty/nginx/conf/nginx.conf.backup
```

### Restore Nginx Configuration

```bash
# Backup current config
sudo cp /usr/local/openresty/nginx/conf/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf.with_plugin

# Remove plugin configuration
sudo vim /usr/local/openresty/nginx/conf/nginx.conf
# Remove lua_package_path, init_by_lua_block, access_by_lua_block, body_filter_by_lua_block

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

## Support

### Getting Help

1. **Documentation**: Check `/docs` directory
2. **Examples**: Check `/examples` directory  
3. **Issues**: GitHub Issues
4. **Logs**: Check nginx error logs với debug level

### Reporting Issues

Khi report issues, include:

1. **System Information**:
   - OS version
   - Nginx/OpenResty version
   - Lua version

2. **Configuration**:
   - nginx.conf (relevant parts)
   - Plugin configuration

3. **Error Logs**:
   - Nginx error logs
   - Plugin debug logs

4. **Reproduction Steps**:
   - Request examples
   - Expected vs actual behavior

### Community

- **GitHub**: Repository issues và discussions
- **Documentation**: Wiki pages
- **Examples**: Community-contributed examples


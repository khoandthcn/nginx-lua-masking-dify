# Setup Guide - Dify v0.15.8

Hướng dẫn cài đặt và cấu hình Nginx Lua Masking Plugin cho Dify v0.15.8

## Yêu Cầu Hệ Thống

### Dify v0.15.8
- Dify Community Edition v0.15.8
- Python 3.10+
- PostgreSQL 14+
- Redis 6.0+

### Nginx/OpenResty
- OpenResty 1.19.9+ hoặc Nginx 1.20+ với lua-resty modules
- lua-resty-json
- lua-resty-http

### Hệ Điều Hành
- Ubuntu 20.04+ / CentOS 8+ / RHEL 8+
- RAM: 4GB minimum, 8GB recommended
- CPU: 2 cores minimum, 4 cores recommended
- Disk: 20GB available space

## Cài Đặt Dify v0.15.8

### 1. Clone Dify Repository
```bash
git clone https://github.com/langgenius/dify.git
cd dify
git checkout 0.15.8
```

### 2. Cấu Hình Environment
```bash
# Copy environment files
cp .env.example .env

# Chỉnh sửa .env file
nano .env
```

**Cấu hình quan trọng cho v0.15.8:**
```env
# API Configuration
API_URL=http://localhost:5001
CONSOLE_URL=http://localhost:3000

# Database
DB_USERNAME=dify
DB_PASSWORD=dify123
DB_HOST=localhost
DB_PORT=5432
DB_DATABASE=dify

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# OpenAI (optional)
OPENAI_API_KEY=your_openai_key
OPENAI_API_BASE=https://api.openai.com/v1
```

### 3. Khởi Động Dify
```bash
# Sử dụng Docker Compose
docker-compose up -d

# Hoặc manual setup
cd api
pip install -r requirements.txt
python app.py

cd ../web
npm install
npm run build
npm start
```

### 4. Xác Minh Cài Đặt
```bash
# Kiểm tra API health
curl http://localhost:5001/health

# Kiểm tra Console
curl http://localhost:3000
```

## Cài Đặt Nginx Lua Masking Plugin

### 1. Cài Đặt OpenResty
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install openresty

# CentOS/RHEL
sudo yum install openresty

# Hoặc compile từ source
wget https://openresty.org/download/openresty-1.21.4.1.tar.gz
tar -xzf openresty-1.21.4.1.tar.gz
cd openresty-1.21.4.1
./configure --with-luajit
make && sudo make install
```

### 2. Cài Đặt Dependencies
```bash
# lua-resty-json
sudo luarocks install lua-resty-json

# lua-resty-http  
sudo luarocks install lua-resty-http

# Hoặc manual install
cd /usr/local/openresty/lualib/resty/
sudo wget https://raw.githubusercontent.com/openresty/lua-resty-json/master/lib/resty/json.lua
```

### 3. Deploy Plugin
```bash
# Extract plugin
tar -xzf nginx-lua-masking-dify-v2.0.tar.gz
cd nginx-lua-masking-dify-v2.0

# Copy files
sudo cp -r lib/* /usr/local/openresty/lualib/
sudo cp config/versions/dify_v0_15_config.json /usr/local/openresty/conf/
sudo cp examples/dify_v0_15_nginx.conf /usr/local/openresty/conf/nginx.conf
```

## Cấu Hình Nginx

### 1. Nginx Configuration
```nginx
# /usr/local/openresty/conf/nginx.conf

worker_processes auto;
error_log /var/log/nginx/error.log;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    
    # Lua package path
    lua_package_path "/usr/local/openresty/lualib/?.lua;;";
    
    # Shared dictionary for caching
    lua_shared_dict masking_cache 10m;
    lua_shared_dict mapping_store 50m;
    
    # Initialize masking plugin
    init_by_lua_block {
        local version_detector = require("version_detector")
        local adapter_factory = require("adapters.adapter_factory")
        
        -- Load configuration
        local config_file = "/usr/local/openresty/conf/dify_v0_15_config.json"
        local config = require("utils").load_json_file(config_file)
        
        -- Initialize global plugin instance
        ngx.shared.masking_cache:set("config", require("utils").json.encode(config))
    }
    
    upstream dify_backend {
        server 127.0.0.1:5001;
        keepalive 32;
    }
    
    server {
        listen 80;
        server_name your-domain.com;
        
        # Health check endpoint
        location /masking/health {
            content_by_lua_block {
                local utils = require("utils")
                ngx.header.content_type = "application/json"
                ngx.say(utils.json.encode({
                    status = "healthy",
                    version = "2.0.0",
                    dify_version = "0.15.8",
                    timestamp = ngx.time()
                }))
            }
        }
        
        # Dify API endpoints with masking
        location ~ ^/v1/(chat-messages|completion-messages|messages) {
            access_by_lua_block {
                local masking_plugin = require("masking_plugin")
                local version_detector = require("version_detector")
                local adapter_factory = require("adapters.adapter_factory")
                
                -- Load configuration
                local config_json = ngx.shared.masking_cache:get("config")
                local config = require("utils").json.decode(config_json)
                
                -- Create version detector
                local detector = version_detector.new()
                detector:detect_version({
                    headers = ngx.req.get_headers(),
                    request_uri = ngx.var.request_uri
                })
                
                -- Create adapter
                local adapter = adapter_factory.create_adapter_with_detection(detector, config)
                if not adapter then
                    ngx.log(ngx.ERR, "Failed to create adapter")
                    ngx.status = 500
                    ngx.say("Internal Server Error")
                    ngx.exit(500)
                end
                
                -- Process request
                ngx.req.read_body()
                local body = ngx.req.get_body_data()
                local headers = ngx.req.get_headers()
                
                local processed_body, error = adapter:process_request(ngx.var.request_uri, ngx.req.get_method(), body, headers)
                if error then
                    ngx.log(ngx.ERR, "Request processing error: " .. (error.message or "unknown"))
                end
                
                if processed_body and processed_body ~= body then
                    ngx.req.set_body_data(processed_body)
                end
            }
            
            # Proxy to Dify backend
            proxy_pass http://dify_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Handle streaming responses
            proxy_buffering off;
            proxy_cache off;
            
            body_filter_by_lua_block {
                local masking_plugin = require("masking_plugin")
                local adapter_factory = require("adapters.adapter_factory")
                
                -- Load configuration
                local config_json = ngx.shared.masking_cache:get("config")
                local config = require("utils").json.decode(config_json)
                
                -- Create adapter for v0.15.8
                local adapter = adapter_factory.create_adapter("0.15.8", config)
                if adapter then
                    local chunk = ngx.arg[1]
                    local eof = ngx.arg[2]
                    
                    if chunk then
                        local processed_chunk = adapter:process_response(ngx.var.request_uri, ngx.req.get_method(), chunk, ngx.header)
                        if processed_chunk then
                            ngx.arg[1] = processed_chunk
                        end
                    end
                end
            }
        }
        
        # Proxy other requests directly
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

### 2. Plugin Configuration
```bash
# Chỉnh sửa cấu hình plugin
sudo nano /usr/local/openresty/conf/dify_v0_15_config.json
```

**Cấu hình quan trọng:**
```json
{
  "version": "0.15.8",
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
  }
}
```

## Khởi Động và Kiểm Tra

### 1. Khởi Động Services
```bash
# Khởi động Dify
cd /path/to/dify
docker-compose up -d

# Khởi động Nginx
sudo systemctl start openresty
sudo systemctl enable openresty
```

### 2. Kiểm Tra Health
```bash
# Kiểm tra plugin health
curl http://your-domain.com/masking/health

# Kiểm tra Dify API
curl http://your-domain.com/v1/chat-messages \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"query": "Hello", "user": "test"}'
```

### 3. Test Masking
```bash
# Test với dữ liệu nhạy cảm
curl -X POST http://your-domain.com/v1/chat-messages \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "My email is test@example.com and IP is 192.168.1.1",
    "user": "test-user"
  }'

# Response sẽ có dữ liệu được unmask
```

## Monitoring và Logging

### 1. Log Files
```bash
# Nginx error log
tail -f /var/log/nginx/error.log

# Nginx access log  
tail -f /var/log/nginx/access.log

# Dify logs
docker-compose logs -f api
```

### 2. Monitoring Metrics
```bash
# Plugin statistics
curl http://your-domain.com/masking/stats

# Dify health
curl http://localhost:5001/health
```

## Troubleshooting

### Common Issues

**1. Plugin không load được**
```bash
# Kiểm tra Lua path
nginx -t

# Kiểm tra dependencies
lua -e "require('utils')"
```

**2. Masking không hoạt động**
```bash
# Kiểm tra configuration
cat /usr/local/openresty/conf/dify_v0_15_config.json

# Kiểm tra logs
grep "masking" /var/log/nginx/error.log
```

**3. Dify connection issues**
```bash
# Kiểm tra Dify backend
curl http://localhost:5001/health

# Kiểm tra network
netstat -tlnp | grep 5001
```

### Performance Tuning

**1. Nginx Configuration**
```nginx
# Tăng worker processes
worker_processes auto;

# Tăng connections
worker_connections 2048;

# Enable caching
lua_shared_dict masking_cache 50m;
```

**2. Dify Configuration**
```env
# Tăng workers
WEB_API_CORS_ALLOW_ORIGINS=*
API_TOOL_DEFAULT_CONNECT_TIMEOUT=300
API_TOOL_DEFAULT_READ_TIMEOUT=300
```

## Security Considerations

### 1. API Key Management
- Sử dụng environment variables cho API keys
- Rotate API keys định kỳ
- Implement rate limiting

### 2. Network Security
- Sử dụng HTTPS trong production
- Restrict access to admin endpoints
- Configure firewall rules

### 3. Data Protection
- Enable masking cho tất cả sensitive data
- Regular backup mapping data
- Monitor for data leaks

## Backup và Recovery

### 1. Configuration Backup
```bash
# Backup configurations
tar -czf dify-v0.15-config-$(date +%Y%m%d).tar.gz \
  /usr/local/openresty/conf/ \
  /path/to/dify/.env
```

### 2. Data Backup
```bash
# Backup Dify database
pg_dump -h localhost -U dify dify > dify-backup-$(date +%Y%m%d).sql

# Backup Redis data
redis-cli --rdb dump.rdb
```

### 3. Recovery Procedures
```bash
# Restore configuration
tar -xzf dify-v0.15-config-backup.tar.gz -C /

# Restore database
psql -h localhost -U dify dify < dify-backup.sql

# Restart services
sudo systemctl restart openresty
docker-compose restart
```

## Next Steps

1. **Production Deployment**: Follow production deployment guide
2. **Monitoring Setup**: Configure comprehensive monitoring
3. **Performance Optimization**: Tune for your specific workload
4. **Security Hardening**: Implement additional security measures
5. **Upgrade Planning**: Plan for future Dify version upgrades


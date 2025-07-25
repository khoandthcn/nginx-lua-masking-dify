# Setup Guide - Dify v1.7.0

Hướng dẫn cài đặt và cấu hình Nginx Lua Masking Plugin cho Dify v1.7.0 với tính năng nâng cao

## Yêu Cầu Hệ Thống

### Dify v1.7.0
- Dify Community Edition v1.7.0+
- Python 3.11+
- PostgreSQL 15+
- Redis 7.0+
- Node.js 18+

### Nginx/OpenResty
- OpenResty 1.21.4+ hoặc Nginx 1.22+ với lua-resty modules
- lua-resty-json
- lua-resty-http
- lua-resty-jwt (cho OAuth support)
- lua-resty-upload (cho file upload)

### Hệ Điều Hành
- Ubuntu 22.04+ / CentOS 9+ / RHEL 9+
- RAM: 8GB minimum, 16GB recommended
- CPU: 4 cores minimum, 8 cores recommended
- Disk: 50GB available space

## Cài Đặt Dify v1.7.0

### 1. Clone Dify Repository
```bash
git clone https://github.com/langgenius/dify.git
cd dify
git checkout 1.7.0
```

### 2. Cấu Hình Environment
```bash
# Copy environment files
cp .env.example .env

# Chỉnh sửa .env file với v1.7.0 specific settings
nano .env
```

**Cấu hình quan trọng cho v1.7.0:**
```env
# API Configuration
API_URL=http://localhost:5001
CONSOLE_URL=http://localhost:3000
WEB_API_CORS_ALLOW_ORIGINS=*

# Database (PostgreSQL 15+)
DB_USERNAME=dify
DB_PASSWORD=dify123
DB_HOST=localhost
DB_PORT=5432
DB_DATABASE=dify

# Redis (v7.0+)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_USE_SSL=false

# OAuth 2.0 Support (New in v1.x)
OAUTH_ENABLED=true
OAUTH_CLIENT_ID=your_oauth_client_id
OAUTH_CLIENT_SECRET=your_oauth_client_secret
OAUTH_REDIRECT_URI=http://localhost:3000/oauth/callback

# File Upload Support (New in v1.x)
UPLOAD_FILE_SIZE_LIMIT=100
UPLOAD_FILE_BATCH_LIMIT=20
UPLOAD_IMAGE_FILE_SIZE_LIMIT=10

# Plugin System (New in v1.x)
PLUGIN_ENABLED=true
PLUGIN_AUTO_UPGRADE=true

# Enhanced Features
EXTERNAL_TRACE_ID_ENABLED=true
AUTO_GENERATE_CONVERSATION_NAME=true

# OpenAI
OPENAI_API_KEY=your_openai_key
OPENAI_API_BASE=https://api.openai.com/v1

# Additional Model Providers
ANTHROPIC_API_KEY=your_anthropic_key
GOOGLE_API_KEY=your_google_key
```

### 3. Khởi Động Dify v1.7.0
```bash
# Sử dụng Docker Compose (Recommended)
docker-compose -f docker-compose.yaml up -d

# Hoặc manual setup với enhanced features
cd api
pip install -r requirements.txt
python app.py

cd ../web  
npm install
npm run build
npm start
```

### 4. Xác Minh Cài Đặt v1.7.0
```bash
# Kiểm tra API health với enhanced info
curl http://localhost:5001/health

# Kiểm tra version info
curl http://localhost:5001/v1/info

# Kiểm tra OAuth endpoints
curl http://localhost:5001/oauth/authorize

# Kiểm tra file upload capability
curl -X POST http://localhost:5001/v1/files/upload \
  -H "Authorization: Bearer your-api-key" \
  -F "file=@test.txt"
```

## Cài Đặt Enhanced Nginx Lua Masking Plugin

### 1. Cài Đặt OpenResty với Enhanced Modules
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install openresty openresty-resty

# Install additional modules for v1.x features
sudo luarocks install lua-resty-jwt
sudo luarocks install lua-resty-upload
sudo luarocks install lua-resty-multipart-parser
sudo luarocks install lua-resty-uuid

# CentOS/RHEL
sudo yum install openresty
sudo yum install luarocks

# Install enhanced dependencies
sudo luarocks install lua-resty-jwt
sudo luarocks install lua-resty-upload
```

### 2. Deploy Enhanced Plugin
```bash
# Extract plugin v2.0
tar -xzf nginx-lua-masking-dify-v2.0.tar.gz
cd nginx-lua-masking-dify-v2.0

# Copy enhanced plugin files
sudo cp -r lib/* /usr/local/openresty/lualib/
sudo cp config/versions/dify_v1_x_config.json /usr/local/openresty/conf/
sudo cp examples/dify_v1_x_nginx.conf /usr/local/openresty/conf/nginx.conf

# Set permissions
sudo chown -R nginx:nginx /usr/local/openresty/lualib/
sudo chmod -R 755 /usr/local/openresty/lualib/
```

## Cấu Hình Enhanced Nginx

### 1. Enhanced Nginx Configuration
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
    
    # Enhanced Lua configuration
    lua_package_path "/usr/local/openresty/lualib/?.lua;;";
    lua_package_cpath "/usr/local/openresty/lualib/?.so;;";
    
    # Shared dictionaries for v1.x features
    lua_shared_dict masking_cache 50m;
    lua_shared_dict mapping_store 100m;
    lua_shared_dict oauth_tokens 10m;
    lua_shared_dict file_uploads 20m;
    lua_shared_dict trace_ids 5m;
    
    # Initialize enhanced masking plugin
    init_by_lua_block {
        local version_detector = require("version_detector")
        local adapter_factory = require("adapters.adapter_factory")
        local utils = require("utils")
        
        -- Load v1.x configuration
        local config_file = "/usr/local/openresty/conf/dify_v1_x_config.json"
        local config = utils.load_json_file(config_file)
        
        -- Initialize global plugin instance with v1.x features
        ngx.shared.masking_cache:set("config", utils.json.encode(config))
        ngx.shared.masking_cache:set("version", "1.7.0")
        
        -- Initialize OAuth if enabled
        if config.oauth and config.oauth.enabled then
            ngx.shared.oauth_tokens:set("client_id", config.oauth.client_id)
            ngx.shared.oauth_tokens:set("client_secret", config.oauth.client_secret)
        end
        
        ngx.log(ngx.INFO, "Enhanced masking plugin initialized for Dify v1.7.0")
    }
    
    # Enhanced upstream configuration
    upstream dify_backend {
        server 127.0.0.1:5001 max_fails=3 fail_timeout=30s;
        keepalive 64;
        keepalive_requests 1000;
        keepalive_timeout 60s;
    }
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=upload:10m rate=2r/s;
    
    server {
        listen 80;
        server_name your-domain.com;
        
        # Enhanced health check with v1.x features
        location /masking/health {
            content_by_lua_block {
                local utils = require("utils")
                local version_detector = require("version_detector")
                
                local detector = version_detector.new()
                local health_info = {
                    status = "healthy",
                    version = "2.0.0",
                    dify_version = "1.7.0",
                    features = {
                        oauth_support = true,
                        file_upload = true,
                        enhanced_metadata = true,
                        streaming_mode = true,
                        plugin_system = true
                    },
                    supported_versions = detector:get_supported_versions(),
                    timestamp = ngx.time()
                }
                
                ngx.header.content_type = "application/json"
                ngx.say(utils.json.encode(health_info))
            }
        }
        
        # OAuth endpoints (New in v1.x)
        location ~ ^/oauth/(authorize|token|refresh|revoke) {
            limit_req zone=api burst=5 nodelay;
            
            access_by_lua_block {
                local oauth_handler = require("oauth_handler")
                local config_json = ngx.shared.masking_cache:get("config")
                local config = require("utils").json.decode(config_json)
                
                if not config.oauth or not config.oauth.enabled then
                    ngx.status = 404
                    ngx.say("OAuth not enabled")
                    ngx.exit(404)
                end
                
                -- Handle OAuth flow
                oauth_handler.process_oauth_request(ngx.var.request_uri, config.oauth)
            }
            
            proxy_pass http://dify_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # File upload endpoint (New in v1.x)
        location /v1/files/upload {
            limit_req zone=upload burst=3 nodelay;
            client_max_body_size 100m;
            
            access_by_lua_block {
                local file_handler = require("file_upload_handler")
                local config_json = ngx.shared.masking_cache:get("config")
                local config = require("utils").json.decode(config_json)
                
                if not config.file_upload or not config.file_upload.enabled then
                    ngx.status = 404
                    ngx.say("File upload not enabled")
                    ngx.exit(404)
                end
                
                -- Process file upload with masking
                file_handler.process_upload(config.file_upload)
            }
            
            proxy_pass http://dify_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # Enhanced API endpoints with v1.x features
        location ~ ^/v1/(chat-messages|completion-messages|messages) {
            limit_req zone=api burst=10 nodelay;
            
            access_by_lua_block {
                local version_detector = require("version_detector")
                local adapter_factory = require("adapters.adapter_factory")
                local utils = require("utils")
                
                -- Load configuration
                local config_json = ngx.shared.masking_cache:get("config")
                local config = utils.json.decode(config_json)
                
                -- Create version detector with enhanced detection
                local detector = version_detector.new()
                local detection_context = {
                    headers = ngx.req.get_headers(),
                    request_uri = ngx.var.request_uri,
                    base_url = "http://localhost:5001",
                    api_key = ngx.req.get_headers()["authorization"]
                }
                
                detector:detect_version(detection_context)
                
                -- Create v1.x adapter
                local adapter = adapter_factory.create_adapter_with_detection(detector, config)
                if not adapter then
                    ngx.log(ngx.ERR, "Failed to create v1.x adapter")
                    ngx.status = 500
                    ngx.say("Internal Server Error")
                    ngx.exit(500)
                end
                
                -- Generate trace ID if enabled
                if config.external_trace and config.external_trace.enabled then
                    local trace_id = utils.generate_uuid()
                    ngx.req.set_header("X-Trace-ID", trace_id)
                    ngx.shared.trace_ids:set(trace_id, ngx.time(), 3600)
                end
                
                -- Process request with enhanced features
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
                
                -- Store adapter in context for response processing
                ngx.ctx.adapter = adapter
            }
            
            # Proxy to Dify backend with enhanced headers
            proxy_pass http://dify_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-API-Version "1.7.0";
            
            # Enhanced streaming support
            proxy_buffering off;
            proxy_cache off;
            proxy_read_timeout 300s;
            proxy_send_timeout 300s;
            
            # Enhanced response processing
            body_filter_by_lua_block {
                local adapter = ngx.ctx.adapter
                if adapter then
                    local chunk = ngx.arg[1]
                    local eof = ngx.arg[2]
                    
                    if chunk and chunk ~= "" then
                        local processed_chunk = adapter:process_response(ngx.var.request_uri, ngx.req.get_method(), chunk, ngx.header)
                        if processed_chunk then
                            ngx.arg[1] = processed_chunk
                        end
                    end
                end
            }
        }
        
        # Stop generation endpoint (New in v1.x)
        location ~ ^/v1/chat-messages/([^/]+)/stop$ {
            limit_req zone=api burst=5 nodelay;
            
            proxy_pass http://dify_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # Suggested questions endpoint (New in v1.x)
        location ~ ^/v1/chat-messages/([^/]+)/suggested$ {
            limit_req zone=api burst=5 nodelay;
            
            access_by_lua_block {
                local adapter = ngx.ctx.adapter or require("adapters.adapter_factory").create_adapter("1.7.0", {})
                if adapter then
                    -- Process suggested questions response
                    ngx.ctx.adapter = adapter
                end
            }
            
            proxy_pass http://dify_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            body_filter_by_lua_block {
                local adapter = ngx.ctx.adapter
                if adapter then
                    local chunk = ngx.arg[1]
                    if chunk then
                        local processed_chunk = adapter:process_response(ngx.var.request_uri, "GET", chunk, ngx.header)
                        if processed_chunk then
                            ngx.arg[1] = processed_chunk
                        end
                    end
                end
            }
        }
        
        # Audio/TTS endpoint (New in v1.x)
        location /v1/audio/speech {
            limit_req zone=api burst=3 nodelay;
            
            access_by_lua_block {
                local config_json = ngx.shared.masking_cache:get("config")
                local config = require("utils").json.decode(config_json)
                
                if not config.features or not config.features.audio_support then
                    ngx.status = 404
                    ngx.say("Audio support not enabled")
                    ngx.exit(404)
                end
                
                -- Process audio request
                local adapter = require("adapters.adapter_factory").create_adapter("1.7.0", config)
                if adapter then
                    ngx.req.read_body()
                    local body = ngx.req.get_body_data()
                    local processed_body = adapter:process_request(ngx.var.request_uri, ngx.req.get_method(), body, ngx.req.get_headers())
                    if processed_body and processed_body ~= body then
                        ngx.req.set_body_data(processed_body)
                    end
                end
            }
            
            proxy_pass http://dify_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # Enhanced statistics endpoint
        location /masking/stats {
            content_by_lua_block {
                local adapter_factory = require("adapters.adapter_factory")
                local utils = require("utils")
                
                local stats = {
                    plugin_version = "2.0.0",
                    dify_version = "1.7.0",
                    adapter_stats = adapter_factory.get_statistics(),
                    cache_stats = {
                        masking_cache_size = ngx.shared.masking_cache:free_space(),
                        mapping_store_size = ngx.shared.mapping_store:free_space(),
                        oauth_tokens_size = ngx.shared.oauth_tokens:free_space()
                    },
                    features_enabled = {
                        oauth_support = true,
                        file_upload = true,
                        enhanced_metadata = true,
                        streaming_mode = true,
                        plugin_system = true
                    },
                    timestamp = ngx.time()
                }
                
                ngx.header.content_type = "application/json"
                ngx.say(utils.json.encode(stats))
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

### 2. Enhanced Plugin Configuration
```bash
# Chỉnh sửa cấu hình v1.x
sudo nano /usr/local/openresty/conf/dify_v1_x_config.json
```

**Cấu hình v1.x với tính năng nâng cao:**
```json
{
  "version": "1.7.0",
  "oauth": {
    "enabled": true,
    "client_id": "your_oauth_client_id",
    "client_secret": "your_oauth_client_secret"
  },
  "file_upload": {
    "enabled": true,
    "max_file_size": 100000000,
    "scan_content": true
  },
  "external_trace": {
    "enabled": true,
    "generate_if_missing": true
  },
  "enhanced_metadata": {
    "enabled": true,
    "mask_retrieval_content": true
  }
}
```

## Khởi Động và Kiểm Tra Enhanced Features

### 1. Khởi Động Services
```bash
# Khởi động Dify v1.7.0
cd /path/to/dify
docker-compose up -d

# Khởi động Enhanced Nginx
sudo systemctl start openresty
sudo systemctl enable openresty
```

### 2. Kiểm Tra Enhanced Health
```bash
# Kiểm tra enhanced plugin health
curl http://your-domain.com/masking/health

# Kiểm tra OAuth endpoints
curl http://your-domain.com/oauth/authorize

# Kiểm tra file upload
curl -X POST http://your-domain.com/v1/files/upload \
  -H "Authorization: Bearer your-api-key" \
  -F "file=@test.txt"
```

### 3. Test Enhanced Features
```bash
# Test với enhanced metadata
curl -X POST http://your-domain.com/v1/chat-messages \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "My email is test@example.com and IP is 192.168.1.1",
    "user": "test-user",
    "auto_generate_name": true,
    "response_mode": "streaming"
  }'

# Test stop generation
curl -X POST http://your-domain.com/v1/chat-messages/message-id/stop \
  -H "Authorization: Bearer your-api-key" \
  -d '{"user": "test-user"}'

# Test suggested questions
curl http://your-domain.com/v1/chat-messages/message-id/suggested \
  -H "Authorization: Bearer your-api-key"
```

## Enhanced Monitoring và Logging

### 1. Enhanced Log Files
```bash
# Enhanced Nginx logs với trace IDs
tail -f /var/log/nginx/error.log | grep "trace_id"

# Dify v1.x logs với enhanced features
docker-compose logs -f api | grep "oauth\|upload\|plugin"
```

### 2. Enhanced Monitoring
```bash
# Enhanced plugin statistics
curl http://your-domain.com/masking/stats

# OAuth token status
curl http://your-domain.com/oauth/status

# File upload statistics
curl http://your-domain.com/files/stats
```

## Production Deployment

### 1. SSL/TLS Configuration
```nginx
server {
    listen 443 ssl http2;
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    # Enhanced SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
}
```

### 2. Performance Optimization
```nginx
# Enhanced worker configuration
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

# Enhanced caching
lua_shared_dict masking_cache 100m;
lua_shared_dict mapping_store 200m;
```

### 3. Security Hardening
```bash
# Firewall rules
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 5001/tcp  # Block direct Dify access

# Rate limiting
limit_req_zone $binary_remote_addr zone=strict:10m rate=1r/s;
```

## Troubleshooting Enhanced Features

### Common v1.x Issues

**1. OAuth không hoạt động**
```bash
# Kiểm tra OAuth configuration
grep -r "oauth" /usr/local/openresty/conf/

# Test OAuth endpoints
curl -v http://your-domain.com/oauth/authorize
```

**2. File upload fails**
```bash
# Kiểm tra file size limits
nginx -T | grep client_max_body_size

# Kiểm tra upload permissions
ls -la /tmp/nginx_uploads/
```

**3. Enhanced metadata missing**
```bash
# Kiểm tra v1.x adapter
grep "enhanced_metadata" /var/log/nginx/error.log

# Test metadata response
curl -v http://your-domain.com/v1/chat-messages
```

## Migration từ v0.15.8

### 1. Backup Data
```bash
# Backup v0.15.8 configuration
cp -r /usr/local/openresty/conf/ /backup/v0.15.8-config/

# Backup Dify v0.15.8 data
pg_dump dify > dify-v0.15.8-backup.sql
```

### 2. Upgrade Process
```bash
# Stop v0.15.8 services
sudo systemctl stop openresty
docker-compose down

# Deploy v1.x configuration
cp config/versions/dify_v1_x_config.json /usr/local/openresty/conf/

# Update Dify to v1.7.0
git checkout 1.7.0
docker-compose up -d

# Start enhanced plugin
sudo systemctl start openresty
```

### 3. Validation
```bash
# Test backward compatibility
curl http://your-domain.com/v1/chat-messages  # Should work

# Test new features
curl http://your-domain.com/oauth/authorize   # New in v1.x
curl http://your-domain.com/v1/files/upload   # New in v1.x
```

## Next Steps

1. **Advanced Configuration**: Configure OAuth providers, file storage
2. **Plugin Development**: Develop custom plugins for v1.x
3. **Monitoring Setup**: Set up comprehensive monitoring for enhanced features
4. **Performance Tuning**: Optimize for v1.x specific workloads
5. **Security Audit**: Conduct security review for enhanced features


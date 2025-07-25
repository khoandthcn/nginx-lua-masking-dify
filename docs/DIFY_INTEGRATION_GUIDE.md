# Hướng Dẫn Tích Hợp Nginx Lua Masking Plugin với Dify v0.15.8

## Tổng Quan

Plugin Nginx Lua Masking được thiết kế đặc biệt để tích hợp với Dify v0.15.8, cung cấp khả năng che giấu (masking) dữ liệu nhạy cảm trong các request và response của Dify message API. Plugin hoạt động trong suốt, đảm bảo dữ liệu nhạy cảm được bảo vệ mà không ảnh hưởng đến chức năng của Dify.

## Tính Năng Chính

### 🔒 Bảo Mật Dữ Liệu
- **Email Masking**: Che giấu địa chỉ email (`user@example.com` → `EMAIL_1`)
- **IP Address Masking**: Che giấu địa chỉ IP (`192.168.1.1` → `IP_1`)
- **Organization Masking**: Che giấu tên tổ chức (`Google` → `ORG_1`)

### 🎯 Tích Hợp Dify Chuyên Biệt
- Hỗ trợ đầy đủ các endpoint của Dify v0.15.8
- Xử lý selective masking theo JSONPath
- Hỗ trợ streaming response (Server-Sent Events)
- Mapping và reverse mapping tự động

### ⚡ Hiệu Suất Cao
- Xử lý < 1ms per request
- Hỗ trợ concurrent requests
- Memory footprint tối ưu
- Graceful error handling

## Kiến Trúc Hệ Thống

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Client App    │───▶│  Nginx + Plugin  │───▶│   Dify Backend  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │  Masking Engine  │
                       │  - Pattern Match │
                       │  - JSON Process  │
                       │  - Mapping Store │
                       └──────────────────┘
```

## Cài Đặt và Cấu Hình

### Yêu Cầu Hệ Thống
- **Nginx**: OpenResty hoặc Nginx với lua-resty-core
- **Lua**: Version 5.1, 5.2, hoặc 5.3
- **Dify**: Version 0.15.8
- **OS**: Ubuntu 20.04+ hoặc CentOS 7+

### Cài Đặt Tự Động

```bash
# Clone repository
git clone <repository-url>
cd nginx-lua-masking

# Chạy script cài đặt (cần quyền root)
sudo ./scripts/deploy_dify.sh -d your-dify-domain.com -b 127.0.0.1:5001

# Kiểm tra trạng thái
curl http://your-dify-domain.com/masking/health
```

### Cài Đặt Thủ Công

#### Bước 1: Cài Đặt Plugin Files
```bash
# Tạo thư mục plugin
sudo mkdir -p /opt/nginx-lua-masking

# Copy files
sudo cp -r lib/ config/ examples/ /opt/nginx-lua-masking/

# Set permissions
sudo chown -R nginx:nginx /opt/nginx-lua-masking
sudo chmod -R 755 /opt/nginx-lua-masking
```

#### Bước 2: Cấu Hình Nginx
```nginx
# /etc/nginx/conf.d/dify-masking.conf

# Lua shared dictionaries
lua_shared_dict masking_mappings 10m;
lua_shared_dict masking_stats 1m;

# Lua package path
lua_package_path "/opt/nginx-lua-masking/lib/?.lua;/opt/nginx-lua-masking/?.lua;;";

# Initialize plugin
init_by_lua_block {
    local dify_adapter = require("lib.dify_adapter")
    
    local config = {
        patterns = {
            email = { 
                enabled = true, 
                regex = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z][a-zA-Z]+", 
                placeholder_prefix = "EMAIL" 
            },
            ipv4 = { 
                enabled = true, 
                regex = "\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b", 
                placeholder_prefix = "IP" 
            },
            organizations = { 
                enabled = true, 
                static_list = {"Google", "Microsoft", "Amazon", "Facebook", "Apple", "OpenAI"}, 
                placeholder_prefix = "ORG" 
            }
        }
    }
    
    _G.dify_masking_adapter = dify_adapter.new(config)
    ngx.log(ngx.INFO, "Dify masking adapter initialized")
}

# Upstream for Dify
upstream dify_backend {
    server 127.0.0.1:5001;  # Điều chỉnh theo địa chỉ Dify của bạn
    keepalive 32;
}

server {
    listen 80;
    server_name your-dify-domain.com;
    
    client_max_body_size 10M;
    proxy_buffering off;
    proxy_request_buffering off;
    
    # Dify API endpoints với masking
    location ~ ^/v1/(chat-messages|completion-messages|messages) {
        # Xử lý request
        access_by_lua_block {
            local adapter = _G.dify_masking_adapter
            if not adapter then return end
            
            local uri = ngx.var.uri
            local method = ngx.var.request_method
            local content_type = ngx.var.content_type or ""
            
            ngx.req.read_body()
            local body = ngx.req.get_body_data()
            
            if body then
                local processed_body, modified = adapter:process_request(uri, method, body, content_type)
                if modified then
                    ngx.req.set_body_data(processed_body)
                end
            end
        }
        
        # Proxy tới Dify
        proxy_pass http://dify_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";
        proxy_http_version 1.1;
        
        # Xử lý response
        body_filter_by_lua_block {
            local adapter = _G.dify_masking_adapter
            if not adapter then return end
            
            local uri = ngx.var.uri
            local method = ngx.var.request_method
            local chunk = ngx.arg[1]
            local is_last = ngx.arg[2]
            
            if chunk and #chunk > 0 and is_last then
                local content_type = ngx.header.content_type or ""
                local processed_chunk = adapter:process_response(uri, method, chunk, content_type)
                ngx.arg[1] = processed_chunk
            end
        }
    }
    
    # Health check endpoint
    location /masking/health {
        access_by_lua_block {
            local adapter = _G.dify_masking_adapter
            if adapter then
                local health = adapter:health_check()
                ngx.header.content_type = "application/json"
                ngx.say('{"status":"' .. health.status .. '","dify_version":"' .. health.dify_version .. '"}')
            else
                ngx.status = 503
                ngx.say('{"status":"error","message":"Adapter not initialized"}')
            end
            ngx.exit(ngx.HTTP_OK)
        }
    }
    
    # Proxy các request khác không cần masking
    location / {
        proxy_pass http://dify_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

#### Bước 3: Khởi Động Dịch Vụ
```bash
# Test cấu hình
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# Kiểm tra trạng thái
curl http://your-domain.com/masking/health
```

## Cấu Hình Chi Tiết

### Cấu Hình Patterns
```json
{
  "patterns": {
    "email": {
      "enabled": true,
      "regex": "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z][a-zA-Z]+",
      "placeholder_prefix": "EMAIL",
      "description": "Email addresses"
    },
    "ipv4": {
      "enabled": true,
      "regex": "\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b",
      "placeholder_prefix": "IP",
      "description": "IPv4 addresses"
    },
    "organizations": {
      "enabled": true,
      "static_list": [
        "Google", "Microsoft", "Amazon", "Facebook", "Apple",
        "OpenAI", "Anthropic", "Cohere", "Hugging Face"
      ],
      "placeholder_prefix": "ORG",
      "case_sensitive": false,
      "whole_words_only": true,
      "description": "Organization names"
    }
  }
}
```

### Cấu Hình Dify Endpoints
```json
{
  "endpoints": {
    "chat_messages": {
      "path": "/v1/chat-messages",
      "method": "POST",
      "request_paths": [
        "$.query",
        "$.inputs.message",
        "$.inputs.user_input",
        "$.inputs.context"
      ],
      "response_paths": [
        "$.answer",
        "$.message.answer",
        "$.message.content",
        "$.agent_thoughts[*].observation"
      ],
      "streaming": true
    }
  }
}
```

## Sử Dụng Plugin

### Test Cơ Bản
```bash
# Test chat messages API
curl -X POST http://your-domain.com/v1/chat-messages \
     -H "Content-Type: application/json" \
     -d '{
       "query": "My email is john.doe@company.com and I work at Google",
       "inputs": {
         "message": "Please contact me at support@mycompany.com"
       }
     }'
```

### Monitoring và Health Check
```bash
# Kiểm tra trạng thái plugin
curl http://your-domain.com/masking/health

# Xem thống kê
curl http://your-domain.com/masking/stats
```

### Logs và Debugging
```bash
# Xem logs Nginx
sudo tail -f /var/log/nginx/error.log

# Xem logs plugin
sudo grep "MASKING-PLUGIN" /var/log/nginx/error.log
```

## Ví Dụ Sử Dụng

### Chat Messages API
**Request gốc:**
```json
{
  "query": "I need help with my account. My email is user@example.com",
  "inputs": {
    "message": "I'm calling from 192.168.1.100 and work at Microsoft"
  },
  "conversation_id": "conv_123"
}
```

**Request sau khi masking:**
```json
{
  "query": "I need help with my account. My email is EMAIL_1",
  "inputs": {
    "message": "I'm calling from IP_1 and work at ORG_1"
  },
  "conversation_id": "conv_123"
}
```

**Response từ Dify:**
```json
{
  "answer": "I'll help you with your account. I'll contact you at EMAIL_1 regarding ORG_1 services from IP_1",
  "message": {
    "content": "Our support team will assist you"
  }
}
```

**Response cuối cùng (sau unmasking):**
```json
{
  "answer": "I'll help you with your account. I'll contact you at user@example.com regarding Microsoft services from 192.168.1.100",
  "message": {
    "content": "Our support team will assist you"
  }
}
```

### Completion Messages API
**Request:**
```json
{
  "query": "Analyze server logs from 10.0.0.1",
  "inputs": {
    "prompt": "Check status of database server at 192.168.1.50"
  }
}
```

**Masked Request:**
```json
{
  "query": "Analyze server logs from IP_1",
  "inputs": {
    "prompt": "Check status of database server at IP_2"
  }
}
```

## Troubleshooting

### Lỗi Thường Gặp

#### 1. Plugin Không Khởi Tạo
**Triệu chứng:** Health check trả về 503
**Nguyên nhân:** Lỗi trong init_by_lua_block
**Giải pháp:**
```bash
# Kiểm tra logs
sudo grep "dify_masking_adapter" /var/log/nginx/error.log

# Kiểm tra đường dẫn Lua
lua_package_path "/opt/nginx-lua-masking/lib/?.lua;;"
```

#### 2. Request Không Được Masking
**Triệu chứng:** Dữ liệu nhạy cảm vẫn hiển thị
**Nguyên nhân:** Endpoint không được nhận diện
**Giải pháp:**
```bash
# Kiểm tra endpoint pattern
location ~ ^/v1/(chat-messages|completion-messages|messages)

# Kiểm tra content-type
Content-Type: application/json
```

#### 3. Response Bị Lỗi
**Triệu chứng:** Response trống hoặc malformed
**Nguyên nhân:** Lỗi trong body_filter_by_lua_block
**Giải pháp:**
```nginx
# Thêm error handling
body_filter_by_lua_block {
    local ok, err = pcall(function()
        -- masking logic here
    end)
    if not ok then
        ngx.log(ngx.ERR, "Masking error: " .. err)
    end
}
```

### Performance Tuning

#### Tối Ưu Memory
```nginx
# Tăng shared dictionary size
lua_shared_dict masking_mappings 50m;
lua_shared_dict masking_stats 5m;

# Tối ưu worker processes
worker_processes auto;
worker_connections 2048;
```

#### Tối Ưu Processing
```json
{
  "processing": {
    "request_timeout": 5000,
    "max_payload_size": 10485760,
    "chunk_size": 8192,
    "max_buffer_size": 1048576
  }
}
```

## Bảo Mật và Best Practices

### Bảo Mật
- **Mapping TTL**: Giới hạn thời gian sống của mapping
- **Access Control**: Hạn chế truy cập endpoint health check
- **Logging**: Không log dữ liệu nhạy cảm
- **HTTPS**: Sử dụng SSL/TLS cho production

### Best Practices
- **Monitoring**: Theo dõi performance và error rates
- **Backup**: Backup cấu hình thường xuyên
- **Testing**: Test trước khi deploy production
- **Documentation**: Ghi chép thay đổi cấu hình

## Kết Luận

Plugin Nginx Lua Masking cung cấp giải pháp bảo mật toàn diện cho Dify v0.15.8, đảm bảo dữ liệu nhạy cảm được bảo vệ mà không ảnh hưởng đến chức năng của ứng dụng. Với hiệu suất cao và tính năng phong phú, plugin sẵn sàng cho môi trường production.

Để được hỗ trợ thêm, vui lòng tham khảo:
- [API Documentation](API.md)
- [Installation Guide](INSTALLATION.md)
- [Architecture Design](architecture.md)


# Quick Start Guide

## 🚀 Cài Đặt Nhanh (5 phút)

### 1. Kiểm tra yêu cầu hệ thống
```bash
# Kiểm tra Nginx với Lua support
nginx -V 2>&1 | grep -q "lua" && echo "✅ Nginx with Lua OK" || echo "❌ Need OpenResty"

# Kiểm tra Lua version
lua -v 2>/dev/null | grep -q "5\.[123]" && echo "✅ Lua OK" || echo "❌ Need Lua 5.1+"
```

### 2. Deploy tự động
```bash
# Chạy script deploy (cần quyền root)
sudo ./scripts/deploy_dify.sh \
    --domain your-dify-domain.com \
    --backend 127.0.0.1:5001

# Hoặc với cấu hình tùy chỉnh
sudo ./scripts/deploy_dify.sh \
    --domain dify.company.com \
    --backend 10.0.0.100:5001 \
    --plugin-dir /opt/masking-plugin
```

### 3. Kiểm tra hoạt động
```bash
# Health check
curl http://your-dify-domain.com/masking/health
# Expected: {"status":"healthy","dify_version":"0.15.8"}

# Test masking
curl -X POST http://your-dify-domain.com/v1/chat-messages \
     -H "Content-Type: application/json" \
     -d '{"query": "My email is test@example.com and I work at Google"}'
```

## 🧪 Test Nhanh

### Test core functions
```bash
# Test pattern matching và JSON processing
lua fixed_test.lua

# Test Dify integration
lua test_dify_integration.lua
```

### Test với Dify thật
```bash
# Chat messages API
curl -X POST http://your-domain.com/v1/chat-messages \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_API_KEY" \
     -d '{
       "query": "My email is john@company.com, contact me at support@mycompany.com",
       "inputs": {
         "message": "I am calling from 192.168.1.100 and work at Microsoft"
       },
       "response_mode": "blocking",
       "user": "user-123"
     }'

# Completion messages API  
curl -X POST http://your-domain.com/v1/completion-messages \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_API_KEY" \
     -d '{
       "query": "Analyze server logs from 10.0.0.1 and 192.168.1.50",
       "inputs": {},
       "response_mode": "blocking",
       "user": "user-123"
     }'
```

## 📊 Monitoring

### Health và Statistics
```bash
# Plugin health
curl http://your-domain.com/masking/health

# Performance statistics
curl http://your-domain.com/masking/stats

# Nginx logs
sudo tail -f /var/log/nginx/error.log | grep "MASKING-PLUGIN"
```

### Performance Metrics
```bash
# Load test với Apache Bench
ab -n 100 -c 10 -H "Content-Type: application/json" \
   -p test_payload.json \
   http://your-domain.com/v1/chat-messages

# Kiểm tra memory usage
ps aux | grep nginx
```

## 🔧 Cấu Hình Nhanh

### Thêm custom patterns
```bash
# Edit config file
sudo nano /opt/nginx-lua-masking/config/dify_config.json

# Thêm pattern mới
{
  "patterns": {
    "phone_numbers": {
      "enabled": true,
      "regex": "\\+?[1-9]\\d{1,14}",
      "placeholder_prefix": "PHONE"
    }
  }
}

# Reload Nginx
sudo systemctl reload nginx
```

### Tùy chỉnh endpoints
```bash
# Thêm endpoint mới vào config
{
  "endpoints": {
    "custom_api": {
      "path": "/v1/custom-endpoint",
      "method": "POST",
      "request_paths": ["$.custom_field"],
      "response_paths": ["$.custom_response"]
    }
  }
}
```

## 🚨 Troubleshooting Nhanh

### Plugin không hoạt động
```bash
# Kiểm tra init
sudo grep "dify_masking_adapter" /var/log/nginx/error.log

# Kiểm tra Lua path
sudo nginx -t
```

### Không có masking
```bash
# Kiểm tra endpoint pattern
sudo grep "location.*chat-messages" /etc/nginx/conf.d/dify-masking.conf

# Test trực tiếp
lua -e "
local adapter = require('lib.dify_adapter')
local a = adapter.new({})
print(a:should_process_request('/v1/chat-messages', 'POST'))
"
```

### Performance issues
```bash
# Tăng shared dict size
lua_shared_dict masking_mappings 50m;

# Tối ưu workers
worker_processes auto;
worker_connections 2048;
```

## 📚 Tài Liệu Đầy Đủ

- **README.md**: Tổng quan và features
- **docs/DIFY_INTEGRATION_GUIDE.md**: Hướng dẫn tích hợp chi tiết
- **docs/API.md**: API documentation
- **docs/INSTALLATION.md**: Hướng dẫn cài đặt manual

## 🎯 Next Steps

1. **Production Setup**: Cấu hình SSL, monitoring, backup
2. **Custom Patterns**: Thêm patterns cho dữ liệu cụ thể của bạn
3. **Performance Tuning**: Điều chỉnh cho traffic cao
4. **Integration**: Tích hợp với logging và monitoring systems

---

**🎉 Chúc mừng! Plugin đã sẵn sàng bảo vệ dữ liệu nhạy cảm trong Dify của bạn!**


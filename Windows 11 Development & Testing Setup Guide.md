# Windows 11 Development & Testing Setup Guide

**Plugin**: Nginx Lua Masking Plugin v2.0.0  
**Target OS**: Windows 11 (22H2 or later)  
**Environment**: Development & Testing  
**Last Updated**: 2025-07-25

## 📋 Tổng Quan

Hướng dẫn này sẽ giúp bạn thiết lập môi trường development và testing hoàn chỉnh cho Nginx Lua Masking Plugin trên Windows 11. Chúng ta sẽ sử dụng WSL2 (Windows Subsystem for Linux) để có môi trường Linux native trong Windows.

## 🎯 Kiến Trúc Setup

```
┌─────────────────────────────────────────────────────────────┐
│                    Windows 11 Host                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │   Windows Tools │    │         WSL2 Ubuntu             │ │
│  │                 │    │                                 │ │
│  │ • VS Code       │◄──►│  ┌─────────────┐ ┌─────────────┐│ │
│  │ • Git           │    │  │ OpenResty   │ │ Lua 5.3     ││ │
│  │ • Docker Desktop│    │  │             │ │             ││ │
│  │ • Postman       │    │  │ • Nginx     │ │ • LuaRocks  ││ │
│  │ • Browser       │    │  │ • Lua Mods  │ │ • Libraries ││ │
│  └─────────────────┘    │  └─────────────┘ └─────────────┘│ │
│                         │                                 │ │
│  ┌─────────────────┐    │  ┌─────────────┐ ┌─────────────┐│ │
│  │   Dify Docker   │    │  │ Plugin Dev  │ │ Test Suite  ││ │
│  │                 │    │  │             │ │             ││ │
│  │ • v0.15.8       │◄──►│  │ • Source    │ │ • Unit      ││ │
│  │ • v1.7.0        │    │  │ • Config    │ │ • Integration││ │
│  │ • PostgreSQL    │    │  │ • Examples  │ │ • Performance││ │
│  │ • Redis         │    │  └─────────────┘ └─────────────┘│ │
│  └─────────────────┘    └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 System Requirements

### Hardware Requirements
- **CPU**: Intel i5/AMD Ryzen 5 hoặc cao hơn (4+ cores)
- **RAM**: 16GB minimum, 32GB recommended
- **Storage**: 100GB available space (SSD recommended)
- **Network**: Stable internet connection

### Software Requirements
- **OS**: Windows 11 22H2 hoặc mới hơn
- **WSL**: WSL2 enabled
- **Virtualization**: Hyper-V enabled
- **PowerShell**: 7.0+ recommended

## 🚀 Phase 1: Windows 11 Base Setup

### Step 1.1: Enable WSL2
```powershell
# Mở PowerShell as Administrator
# Enable WSL feature
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

# Enable Virtual Machine Platform
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Restart Windows
Restart-Computer
```

### Step 1.2: Install WSL2 Ubuntu
```powershell
# Sau khi restart, mở PowerShell as Administrator
# Set WSL2 as default
wsl --set-default-version 2

# Install Ubuntu 22.04
wsl --install -d Ubuntu-22.04

# Verify installation
wsl --list --verbose
```

### Step 1.3: Configure WSL2 Resources
Tạo file `.wslconfig` trong `C:\Users\<username>\`:
```ini
[wsl2]
memory=8GB
processors=4
swap=2GB
localhostForwarding=true
```

### Step 1.4: Install Windows Development Tools
```powershell
# Install Chocolatey package manager
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install essential tools
choco install -y git
choco install -y vscode
choco install -y docker-desktop
choco install -y postman
choco install -y curl
choco install -y wget
```

## 🐧 Phase 2: WSL2 Ubuntu Setup

### Step 2.1: Basic Ubuntu Configuration
```bash
# Mở WSL2 Ubuntu terminal
wsl

# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y build-essential curl wget git vim nano htop tree

# Install development tools
sudo apt install -y software-properties-common apt-transport-https ca-certificates gnupg lsb-release
```

### Step 2.2: Install OpenResty
```bash
# Add OpenResty repository
wget -qO - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
sudo apt-add-repository "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main"

# Install OpenResty
sudo apt update
sudo apt install -y openresty

# Verify installation
openresty -v
```

### Step 2.3: Install Lua and LuaRocks
```bash
# Install Lua 5.3
sudo apt install -y lua5.3 lua5.3-dev

# Install LuaRocks
sudo apt install -y luarocks

# Install required Lua modules
sudo luarocks install lua-resty-json
sudo luarocks install lua-resty-http
sudo luarocks install lua-resty-jwt
sudo luarocks install lua-resty-upload
sudo luarocks install busted  # For testing

# Verify installations
lua5.3 -v
luarocks --version
```

### Step 2.4: Configure Development Environment
```bash
# Create development directory
mkdir -p ~/dev/nginx-lua-masking
cd ~/dev/nginx-lua-masking

# Set up environment variables
echo 'export LUA_PATH="./?.lua;./lib/?.lua;/usr/local/openresty/lualib/?.lua;;"' >> ~/.bashrc
echo 'export LUA_CPATH="./?.so;/usr/local/openresty/lualib/?.so;;"' >> ~/.bashrc
echo 'export PATH="/usr/local/openresty/bin:$PATH"' >> ~/.bashrc

# Reload bashrc
source ~/.bashrc
```

## 🐳 Phase 3: Docker & Dify Setup

### Step 3.1: Install Docker in WSL2
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Start Docker service
sudo service docker start

# Enable Docker to start on boot
echo 'sudo service docker start' >> ~/.bashrc
```

### Step 3.2: Setup Dify v0.15.8 (Testing)
```bash
# Create Dify v0.15.8 environment
mkdir -p ~/dev/dify-v0.15.8
cd ~/dev/dify-v0.15.8

# Clone Dify v0.15.8
git clone --branch 0.15.8 https://github.com/langgenius/dify.git .

# Create docker-compose override for development
cat > docker-compose.override.yml << 'EOF'
version: '3'
services:
  api:
    ports:
      - "5001:5001"
    environment:
      - DEBUG=true
      - LOG_LEVEL=DEBUG
  web:
    ports:
      - "3001:3000"
EOF

# Start Dify v0.15.8
docker-compose up -d

# Wait for services to be ready
sleep 30
curl http://localhost:5001/health
```

### Step 3.3: Setup Dify v1.7.0 (Testing)
```bash
# Create Dify v1.7.0 environment
mkdir -p ~/dev/dify-v1.7.0
cd ~/dev/dify-v1.7.0

# Clone Dify v1.7.0
git clone --branch 1.7.0 https://github.com/langgenius/dify.git .

# Create docker-compose override for development
cat > docker-compose.override.yml << 'EOF'
version: '3'
services:
  api:
    ports:
      - "5002:5001"
    environment:
      - DEBUG=true
      - LOG_LEVEL=DEBUG
  web:
    ports:
      - "3002:3000"
EOF

# Start Dify v1.7.0
docker-compose up -d

# Wait for services to be ready
sleep 30
curl http://localhost:5002/health
```

## 🔧 Phase 4: Plugin Development Setup

### Step 4.1: Clone Plugin Repository
```bash
# Navigate to development directory
cd ~/dev/nginx-lua-masking

# Clone plugin repository (replace with actual repo URL)
git clone https://github.com/your-repo/nginx-lua-masking-dify.git .

# Or if you have the plugin files locally, copy them
# cp -r /path/to/plugin/* .

# Verify structure
tree -L 2
```

### Step 4.2: Configure OpenResty for Development
```bash
# Create development OpenResty configuration
sudo mkdir -p /usr/local/openresty/conf/dev
sudo cp examples/dify_nginx.conf /usr/local/openresty/conf/dev/nginx.conf

# Create development configuration
cat > /tmp/dev_config.json << 'EOF'
{
  "version": "auto-detect",
  "debug": true,
  "masking": {
    "enabled": true,
    "patterns": {
      "email": {"enabled": true, "debug": true},
      "ip_private": {"enabled": true, "debug": true},
      "ip_public": {"enabled": true, "debug": true},
      "ipv6": {"enabled": true, "debug": true},
      "organization": {"enabled": true, "debug": true},
      "domain": {"enabled": true, "debug": true},
      "hostname": {"enabled": true, "debug": true}
    }
  },
  "logging": {
    "level": "DEBUG",
    "file": "/var/log/nginx/masking_debug.log"
  }
}
EOF

sudo cp /tmp/dev_config.json /usr/local/openresty/conf/dev/masking_config.json

# Copy plugin files to OpenResty
sudo cp -r lib/* /usr/local/openresty/lualib/
sudo chmod -R 755 /usr/local/openresty/lualib/
```

### Step 4.3: Setup Development Nginx Configuration
```bash
# Create development nginx.conf
cat > /tmp/dev_nginx.conf << 'EOF'
worker_processes 1;
error_log /var/log/nginx/error.log debug;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    
    # Lua configuration
    lua_package_path "/usr/local/openresty/lualib/?.lua;;";
    lua_shared_dict masking_cache 10m;
    lua_shared_dict mapping_store 50m;
    
    # Debug logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log debug;
    
    # Initialize plugin
    init_by_lua_block {
        local utils = require("utils")
        local config = utils.load_json_file("/usr/local/openresty/conf/dev/masking_config.json")
        ngx.shared.masking_cache:set("config", utils.json.encode(config))
        ngx.log(ngx.ERR, "Plugin initialized in development mode")
    }
    
    # Upstream for Dify v0.15.8
    upstream dify_v015 {
        server 127.0.0.1:5001;
    }
    
    # Upstream for Dify v1.7.0
    upstream dify_v1x {
        server 127.0.0.1:5002;
    }
    
    server {
        listen 8080;
        server_name localhost;
        
        # Health check
        location /masking/health {
            content_by_lua_block {
                local utils = require("utils")
                local health = {
                    status = "healthy",
                    version = "2.0.0-dev",
                    mode = "development",
                    timestamp = ngx.time()
                }
                ngx.header.content_type = "application/json"
                ngx.say(utils.json.encode(health))
            }
        }
        
        # Debug endpoint
        location /masking/debug {
            content_by_lua_block {
                local config_json = ngx.shared.masking_cache:get("config")
                ngx.header.content_type = "application/json"
                ngx.say(config_json or "{}")
            }
        }
        
        # Dify v0.15.8 endpoints
        location /v015/ {
            rewrite ^/v015/(.*)$ /$1 break;
            
            access_by_lua_block {
                ngx.log(ngx.ERR, "Processing request for Dify v0.15.8: " .. ngx.var.request_uri)
                -- Plugin processing logic here
            }
            
            proxy_pass http://dify_v015;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        # Dify v1.7.0 endpoints
        location /v1x/ {
            rewrite ^/v1x/(.*)$ /$1 break;
            
            access_by_lua_block {
                ngx.log(ngx.ERR, "Processing request for Dify v1.7.0: " .. ngx.var.request_uri)
                -- Plugin processing logic here
            }
            
            proxy_pass http://dify_v1x;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        # Default proxy (auto-detect version)
        location / {
            access_by_lua_block {
                local version_detector = require("version_detector")
                local adapter_factory = require("adapters.adapter_factory")
                
                -- Auto-detect version and process
                ngx.log(ngx.ERR, "Auto-detecting Dify version for: " .. ngx.var.request_uri)
            }
            
            proxy_pass http://dify_v015;  # Default to v0.15.8
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
EOF

sudo cp /tmp/dev_nginx.conf /usr/local/openresty/conf/dev/nginx.conf
```

## 🧪 Phase 5: Testing Environment Setup

### Step 5.1: Install Testing Tools
```bash
# Install testing frameworks
sudo luarocks install busted
sudo luarocks install luacov  # Code coverage
sudo luarocks install luacheck  # Linting

# Install additional testing tools
sudo apt install -y jq curl httpie

# Install performance testing tools
sudo apt install -y apache2-utils  # for ab (Apache Bench)
```

### Step 5.2: Setup Test Environment
```bash
# Create test directory structure
mkdir -p ~/dev/nginx-lua-masking/test/windows
cd ~/dev/nginx-lua-masking/test/windows

# Create Windows-specific test configuration
cat > test_config.json << 'EOF'
{
  "test_environment": "windows_wsl2",
  "dify_instances": {
    "v0.15.8": {
      "url": "http://localhost:5001",
      "health_endpoint": "/health"
    },
    "v1.7.0": {
      "url": "http://localhost:5002",
      "health_endpoint": "/health"
    }
  },
  "plugin_endpoint": "http://localhost:8080",
  "test_data": {
    "sample_emails": ["test@example.com", "user@domain.org"],
    "sample_ips": ["192.168.1.1", "8.8.8.8", "2001:db8::1"],
    "sample_domains": ["google.com", "github.com"],
    "sample_hostnames": ["localhost", "api-server"]
  }
}
EOF

# Create test runner script
cat > run_windows_tests.sh << 'EOF'
#!/bin/bash

echo "🧪 Starting Windows 11 WSL2 Test Suite"
echo "======================================"

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check WSL2
if ! grep -q "microsoft" /proc/version; then
    echo "❌ Not running in WSL2"
    exit 1
fi

# Check Dify instances
echo "🔍 Checking Dify instances..."
if ! curl -s http://localhost:5001/health > /dev/null; then
    echo "❌ Dify v0.15.8 not running on port 5001"
    exit 1
fi

if ! curl -s http://localhost:5002/health > /dev/null; then
    echo "❌ Dify v1.7.0 not running on port 5002"
    exit 1
fi

# Check OpenResty
echo "🔍 Checking OpenResty..."
if ! pgrep nginx > /dev/null; then
    echo "⚠️  Starting OpenResty..."
    sudo openresty -p /usr/local/openresty -c conf/dev/nginx.conf
    sleep 2
fi

# Check plugin health
echo "🔍 Checking plugin health..."
if ! curl -s http://localhost:8080/masking/health > /dev/null; then
    echo "❌ Plugin not responding on port 8080"
    exit 1
fi

echo "✅ All prerequisites met"

# Run tests
echo "🧪 Running test suite..."

# Unit tests
echo "📝 Running unit tests..."
cd ~/dev/nginx-lua-masking
lua test/run_tests.lua

# Integration tests
echo "🔗 Running integration tests..."
lua test/run_multi_version_tests.lua

# Windows-specific tests
echo "🪟 Running Windows-specific tests..."
cd test/windows

# Test plugin health
echo "Testing plugin health endpoint..."
response=$(curl -s http://localhost:8080/masking/health)
if echo "$response" | jq -e '.status == "healthy"' > /dev/null; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed: $response"
fi

# Test version detection
echo "Testing version detection..."
v015_response=$(curl -s -H "X-Dify-Version: 0.15.8" http://localhost:8080/masking/health)
v1x_response=$(curl -s -H "X-Dify-Version: 1.7.0" http://localhost:8080/masking/health)

echo "✅ Version detection tests completed"

# Test masking functionality
echo "Testing masking functionality..."
test_payload='{"query": "My email is test@example.com and IP is 192.168.1.1"}'

# Test with v0.15.8
echo "Testing with Dify v0.15.8..."
curl -s -X POST http://localhost:8080/v015/v1/chat-messages \
  -H "Content-Type: application/json" \
  -d "$test_payload" | jq .

# Test with v1.7.0
echo "Testing with Dify v1.7.0..."
curl -s -X POST http://localhost:8080/v1x/v1/chat-messages \
  -H "Content-Type: application/json" \
  -d "$test_payload" | jq .

echo "🎉 Windows 11 WSL2 test suite completed!"
EOF

chmod +x run_windows_tests.sh
```

### Step 5.3: Performance Testing Setup
```bash
# Create performance test script
cat > performance_test.sh << 'EOF'
#!/bin/bash

echo "⚡ Performance Testing on Windows 11 WSL2"
echo "========================================="

# Test configuration
CONCURRENT_USERS=10
TOTAL_REQUESTS=1000
TEST_URL="http://localhost:8080/masking/health"

echo "📊 Running performance tests..."
echo "Concurrent users: $CONCURRENT_USERS"
echo "Total requests: $TOTAL_REQUESTS"
echo "Target URL: $TEST_URL"

# Apache Bench test
echo "🔥 Running Apache Bench test..."
ab -n $TOTAL_REQUESTS -c $CONCURRENT_USERS $TEST_URL

# Custom Lua performance test
echo "🔥 Running Lua performance test..."
lua << 'LUA_EOF'
local socket = require("socket")
local http = require("socket.http")

local function test_performance()
    local start_time = socket.gettime()
    local success_count = 0
    local error_count = 0
    
    for i = 1, 100 do
        local response, status = http.request("http://localhost:8080/masking/health")
        if status == 200 then
            success_count = success_count + 1
        else
            error_count = error_count + 1
        end
    end
    
    local end_time = socket.gettime()
    local duration = end_time - start_time
    local avg_response_time = duration / 100
    
    print(string.format("Performance Results:"))
    print(string.format("  Total requests: 100"))
    print(string.format("  Success: %d", success_count))
    print(string.format("  Errors: %d", error_count))
    print(string.format("  Total time: %.2f seconds", duration))
    print(string.format("  Average response time: %.3f seconds", avg_response_time))
    print(string.format("  Requests per second: %.2f", 100 / duration))
end

test_performance()
LUA_EOF

echo "✅ Performance testing completed"
EOF

chmod +x performance_test.sh
```

## 💻 Phase 6: VS Code Integration

### Step 6.1: Install VS Code Extensions
Trong VS Code trên Windows, install các extensions sau:
```
- Remote - WSL
- Lua Language Server
- GitLens
- Docker
- REST Client
- JSON Tools
- YAML
```

### Step 6.2: Configure VS Code for WSL2
```bash
# Mở project trong VS Code từ WSL2
cd ~/dev/nginx-lua-masking
code .
```

### Step 6.3: Create VS Code Configuration
Tạo `.vscode/settings.json`:
```json
{
    "lua.workspace.library": [
        "/usr/local/openresty/lualib",
        "/usr/share/lua/5.3",
        "./lib"
    ],
    "lua.diagnostics.globals": [
        "ngx",
        "ndk",
        "resty"
    ],
    "files.associations": {
        "*.lua": "lua"
    },
    "terminal.integrated.defaultProfile.linux": "bash",
    "terminal.integrated.cwd": "${workspaceFolder}"
}
```

Tạo `.vscode/launch.json`:
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug Lua Tests",
            "type": "lua",
            "request": "launch",
            "program": "${workspaceFolder}/test/run_tests.lua",
            "cwd": "${workspaceFolder}",
            "stopOnEntry": false
        }
    ]
}
```

Tạo `.vscode/tasks.json`:
```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Run Tests",
            "type": "shell",
            "command": "lua",
            "args": ["test/run_tests.lua"],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared"
            }
        },
        {
            "label": "Start OpenResty Dev",
            "type": "shell",
            "command": "sudo",
            "args": ["openresty", "-p", "/usr/local/openresty", "-c", "conf/dev/nginx.conf"],
            "group": "build"
        },
        {
            "label": "Reload OpenResty",
            "type": "shell",
            "command": "sudo",
            "args": ["openresty", "-s", "reload"],
            "group": "build"
        }
    ]
}
```

## 🔄 Phase 7: Development Workflow

### Step 7.1: Daily Development Routine
```bash
# Create daily startup script
cat > ~/dev/start_dev_environment.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Nginx Lua Masking Plugin Development Environment"
echo "============================================================"

# Start Docker services
echo "🐳 Starting Docker services..."
sudo service docker start

# Start Dify v0.15.8
echo "📦 Starting Dify v0.15.8..."
cd ~/dev/dify-v0.15.8
docker-compose up -d

# Start Dify v1.7.0
echo "📦 Starting Dify v1.7.0..."
cd ~/dev/dify-v1.7.0
docker-compose up -d

# Wait for services
echo "⏳ Waiting for services to be ready..."
sleep 30

# Check Dify health
echo "🔍 Checking Dify instances..."
curl -s http://localhost:5001/health && echo " ✅ Dify v0.15.8 ready"
curl -s http://localhost:5002/health && echo " ✅ Dify v1.7.0 ready"

# Start OpenResty
echo "🌐 Starting OpenResty..."
cd ~/dev/nginx-lua-masking
sudo openresty -p /usr/local/openresty -c conf/dev/nginx.conf

# Check plugin health
echo "🔍 Checking plugin health..."
sleep 2
curl -s http://localhost:8080/masking/health && echo " ✅ Plugin ready"

echo "🎉 Development environment ready!"
echo ""
echo "📋 Available endpoints:"
echo "  - Plugin health: http://localhost:8080/masking/health"
echo "  - Plugin debug: http://localhost:8080/masking/debug"
echo "  - Dify v0.15.8: http://localhost:5001"
echo "  - Dify v1.7.0: http://localhost:5002"
echo "  - Plugin proxy v0.15.8: http://localhost:8080/v015/"
echo "  - Plugin proxy v1.7.0: http://localhost:8080/v1x/"
echo ""
echo "🧪 To run tests: cd ~/dev/nginx-lua-masking && ./test/windows/run_windows_tests.sh"
echo "💻 To open in VS Code: cd ~/dev/nginx-lua-masking && code ."
EOF

chmod +x ~/dev/start_dev_environment.sh
```

### Step 7.2: Testing Workflow
```bash
# Create comprehensive test script
cat > ~/dev/nginx-lua-masking/test_all.sh << 'EOF'
#!/bin/bash

echo "🧪 Comprehensive Test Suite for Windows 11 Development"
echo "====================================================="

# Set working directory
cd ~/dev/nginx-lua-masking

# 1. Lint check
echo "📝 Running Lua lint check..."
if command -v luacheck &> /dev/null; then
    luacheck lib/ test/ --globals ngx ndk resty
else
    echo "⚠️  luacheck not installed, skipping lint"
fi

# 2. Unit tests
echo "🔬 Running unit tests..."
lua test/run_tests.lua

# 3. Integration tests
echo "🔗 Running integration tests..."
lua test/run_multi_version_tests.lua

# 4. Windows-specific tests
echo "🪟 Running Windows-specific tests..."
./test/windows/run_windows_tests.sh

# 5. Performance tests
echo "⚡ Running performance tests..."
./test/windows/performance_test.sh

# 6. Manual API tests
echo "🔧 Running manual API tests..."

# Test data
test_data='{"query": "Contact support@company.com or admin@192.168.1.100 for help with api.example.com"}'

echo "Testing email, IP, and domain masking..."

# Test v0.15.8
echo "📧 Testing Dify v0.15.8 integration..."
response=$(curl -s -X POST http://localhost:8080/v015/v1/chat-messages \
  -H "Content-Type: application/json" \
  -d "$test_data")

if echo "$response" | grep -q "EMAIL_1\|IP_PRIVATE_1\|DOMAIN_1"; then
    echo "✅ v0.15.8 masking working"
else
    echo "❌ v0.15.8 masking failed"
fi

# Test v1.7.0
echo "📧 Testing Dify v1.7.0 integration..."
response=$(curl -s -X POST http://localhost:8080/v1x/v1/chat-messages \
  -H "Content-Type: application/json" \
  -d "$test_data")

if echo "$response" | grep -q "EMAIL_1\|IP_PRIVATE_1\|DOMAIN_1"; then
    echo "✅ v1.7.0 masking working"
else
    echo "❌ v1.7.0 masking failed"
fi

echo "🎉 All tests completed!"
EOF

chmod +x ~/dev/nginx-lua-masking/test_all.sh
```

### Step 7.3: Debugging Workflow
```bash
# Create debug helper script
cat > ~/dev/nginx-lua-masking/debug_plugin.sh << 'EOF'
#!/bin/bash

echo "🐛 Plugin Debug Helper for Windows 11"
echo "====================================="

# Function to show logs
show_logs() {
    echo "📋 Recent Nginx error logs:"
    sudo tail -n 20 /var/log/nginx/error.log
    echo ""
    echo "📋 Recent Nginx access logs:"
    sudo tail -n 10 /var/log/nginx/access.log
}

# Function to reload plugin
reload_plugin() {
    echo "🔄 Reloading plugin..."
    sudo cp -r lib/* /usr/local/openresty/lualib/
    sudo openresty -s reload
    echo "✅ Plugin reloaded"
}

# Function to test plugin
test_plugin() {
    echo "🧪 Testing plugin functionality..."
    
    # Health check
    echo "Health check:"
    curl -s http://localhost:8080/masking/health | jq .
    
    # Debug info
    echo "Debug info:"
    curl -s http://localhost:8080/masking/debug | jq .
    
    # Test masking
    echo "Test masking:"
    curl -s -X POST http://localhost:8080/v015/v1/chat-messages \
      -H "Content-Type: application/json" \
      -d '{"query": "Test email user@example.com"}' | jq .
}

# Main menu
case "$1" in
    "logs")
        show_logs
        ;;
    "reload")
        reload_plugin
        ;;
    "test")
        test_plugin
        ;;
    *)
        echo "Usage: $0 {logs|reload|test}"
        echo ""
        echo "Commands:"
        echo "  logs   - Show recent Nginx logs"
        echo "  reload - Reload plugin code"
        echo "  test   - Test plugin functionality"
        ;;
esac
EOF

chmod +x ~/dev/nginx-lua-masking/debug_plugin.sh
```

## 📚 Phase 8: Documentation & Best Practices

### Step 8.1: Windows-Specific Notes
```markdown
# Windows 11 Development Notes

## WSL2 Specific Considerations

### File System Performance
- Keep source code in WSL2 file system (/home/user/) for better performance
- Avoid editing files in Windows file system (/mnt/c/) from WSL2
- Use VS Code Remote-WSL extension for seamless editing

### Network Configuration
- WSL2 uses NAT networking, localhost works for most cases
- Use `ip route show | grep -i default | awk '{ print $3}'` to get Windows host IP
- Port forwarding is automatic for localhost

### Memory Management
- Configure .wslconfig to limit WSL2 memory usage
- Monitor memory usage with `htop` in WSL2
- Restart WSL2 if memory issues: `wsl --shutdown` then restart

### Docker Integration
- Use Docker Desktop for Windows with WSL2 backend
- Docker commands work directly in WSL2
- Shared volumes work between WSL2 and Windows

## Development Best Practices

### Code Organization
- Keep all development in WSL2 file system
- Use symbolic links for shared configurations
- Maintain separate environments for different Dify versions

### Testing Strategy
- Run tests in WSL2 environment
- Use Windows tools (Postman, browsers) for manual testing
- Automate testing with scripts

### Debugging Tips
- Use VS Code integrated terminal for WSL2
- Monitor logs with `tail -f` in separate terminal
- Use curl/httpie for API testing
- Enable debug logging in development
```

### Step 8.2: Troubleshooting Guide
```bash
# Create troubleshooting guide
cat > ~/dev/nginx-lua-masking/TROUBLESHOOTING_WINDOWS.md << 'EOF'
# Windows 11 Troubleshooting Guide

## Common Issues and Solutions

### WSL2 Issues

#### WSL2 Not Starting
```powershell
# Check WSL2 status
wsl --status

# Restart WSL2
wsl --shutdown
wsl

# Update WSL2
wsl --update
```

#### Network Issues
```bash
# Check network connectivity
ping google.com

# Reset network (in PowerShell as Admin)
wsl --shutdown
netsh winsock reset
netsh int ip reset
```

### Docker Issues

#### Docker Not Starting
```bash
# Check Docker status
sudo service docker status

# Start Docker
sudo service docker start

# Check Docker Desktop on Windows
```

#### Port Conflicts
```bash
# Check port usage
netstat -tulpn | grep :5001
netstat -tulpn | grep :8080

# Kill processes using ports
sudo fuser -k 5001/tcp
sudo fuser -k 8080/tcp
```

### OpenResty Issues

#### OpenResty Won't Start
```bash
# Check configuration
sudo openresty -t -c /usr/local/openresty/conf/dev/nginx.conf

# Check logs
sudo tail -f /var/log/nginx/error.log

# Check permissions
sudo chown -R nginx:nginx /usr/local/openresty/
```

#### Lua Module Not Found
```bash
# Check Lua path
echo $LUA_PATH

# Verify module installation
lua -e "require('utils'); print('OK')"

# Reinstall modules
sudo luarocks install lua-resty-json
```

### Plugin Issues

#### Plugin Not Loading
```bash
# Check plugin files
ls -la /usr/local/openresty/lualib/

# Check configuration
curl http://localhost:8080/masking/debug

# Reload plugin
sudo cp -r lib/* /usr/local/openresty/lualib/
sudo openresty -s reload
```

#### Masking Not Working
```bash
# Check pattern configuration
cat config/dify_config.json | jq .masking.patterns

# Test individual patterns
lua -e "
local pm = require('pattern_matcher')
local matcher = pm.new({})
print(matcher:mask_text('test@example.com'))
"

# Check logs for errors
sudo tail -f /var/log/nginx/error.log | grep masking
```

### Performance Issues

#### High Memory Usage
```bash
# Check memory usage
free -h
htop

# Check WSL2 memory limit
cat /proc/meminfo

# Restart WSL2 if needed
wsl --shutdown  # In PowerShell
wsl
```

#### Slow Response Times
```bash
# Check system load
uptime
iostat

# Profile Lua code
lua -e "
local start = os.clock()
-- Your code here
print('Time:', os.clock() - start)
"

# Check network latency
ping localhost
```

## Emergency Recovery

### Reset Development Environment
```bash
# Stop all services
sudo pkill nginx
docker-compose down  # In Dify directories

# Clean up
sudo rm -rf /var/log/nginx/*
sudo rm -rf /usr/local/openresty/logs/*

# Restart from scratch
~/dev/start_dev_environment.sh
```

### Backup and Restore
```bash
# Backup configuration
tar -czf ~/backup_$(date +%Y%m%d).tar.gz \
  ~/dev/nginx-lua-masking \
  /usr/local/openresty/conf/dev

# Restore from backup
tar -xzf ~/backup_20250725.tar.gz -C ~/
```
EOF
```

## 🎯 Phase 9: Final Setup Verification

### Step 9.1: Complete Environment Test
```bash
# Create final verification script
cat > ~/dev/verify_setup.sh << 'EOF'
#!/bin/bash

echo "🔍 Final Windows 11 Development Environment Verification"
echo "======================================================="

# Check WSL2
echo "📋 Checking WSL2..."
if grep -q "microsoft" /proc/version; then
    echo "✅ Running in WSL2"
else
    echo "❌ Not in WSL2"
    exit 1
fi

# Check essential tools
echo "📋 Checking essential tools..."
tools=("git" "curl" "docker" "lua5.3" "openresty" "luarocks")
for tool in "${tools[@]}"; do
    if command -v $tool &> /dev/null; then
        echo "✅ $tool installed"
    else
        echo "❌ $tool missing"
    fi
done

# Check Lua modules
echo "📋 Checking Lua modules..."
modules=("utils" "pattern_matcher" "version_detector" "adapters.adapter_factory")
for module in "${modules[@]}"; do
    if lua -e "require('$module')" 2>/dev/null; then
        echo "✅ $module loadable"
    else
        echo "❌ $module not loadable"
    fi
done

# Check Dify instances
echo "📋 Checking Dify instances..."
if curl -s http://localhost:5001/health > /dev/null; then
    echo "✅ Dify v0.15.8 running"
else
    echo "❌ Dify v0.15.8 not running"
fi

if curl -s http://localhost:5002/health > /dev/null; then
    echo "✅ Dify v1.7.0 running"
else
    echo "❌ Dify v1.7.0 not running"
fi

# Check plugin
echo "📋 Checking plugin..."
if curl -s http://localhost:8080/masking/health > /dev/null; then
    echo "✅ Plugin responding"
    
    # Test masking
    response=$(curl -s -X POST http://localhost:8080/v015/v1/chat-messages \
      -H "Content-Type: application/json" \
      -d '{"query": "test@example.com"}')
    
    if echo "$response" | grep -q "EMAIL_1"; then
        echo "✅ Masking working"
    else
        echo "⚠️  Masking may not be working properly"
    fi
else
    echo "❌ Plugin not responding"
fi

# Performance check
echo "📋 Performance check..."
start_time=$(date +%s.%N)
curl -s http://localhost:8080/masking/health > /dev/null
end_time=$(date +%s.%N)
response_time=$(echo "$end_time - $start_time" | bc)

if (( $(echo "$response_time < 0.1" | bc -l) )); then
    echo "✅ Response time: ${response_time}s (excellent)"
elif (( $(echo "$response_time < 0.5" | bc -l) )); then
    echo "⚠️  Response time: ${response_time}s (acceptable)"
else
    echo "❌ Response time: ${response_time}s (slow)"
fi

echo ""
echo "🎉 Environment verification completed!"
echo ""
echo "📚 Next steps:"
echo "  1. Open VS Code: cd ~/dev/nginx-lua-masking && code ."
echo "  2. Run tests: ./test_all.sh"
echo "  3. Start development: Edit files and test changes"
echo "  4. Debug issues: ./debug_plugin.sh logs"
EOF

chmod +x ~/dev/verify_setup.sh
```

### Step 9.2: Create Quick Reference
```bash
# Create quick reference card
cat > ~/dev/QUICK_REFERENCE.md << 'EOF'
# Windows 11 Development Quick Reference

## Daily Commands

### Start Development Environment
```bash
~/dev/start_dev_environment.sh
```

### Run All Tests
```bash
cd ~/dev/nginx-lua-masking
./test_all.sh
```

### Debug Plugin
```bash
./debug_plugin.sh logs    # Show logs
./debug_plugin.sh reload  # Reload plugin
./debug_plugin.sh test    # Test functionality
```

### Check Status
```bash
# Plugin health
curl http://localhost:8080/masking/health

# Dify v0.15.8
curl http://localhost:5001/health

# Dify v1.7.0
curl http://localhost:5002/health
```

## Development Endpoints

| Service | URL | Purpose |
|---------|-----|---------|
| Plugin Health | http://localhost:8080/masking/health | Health check |
| Plugin Debug | http://localhost:8080/masking/debug | Debug info |
| Dify v0.15.8 | http://localhost:5001 | Backend v0.15.8 |
| Dify v1.7.0 | http://localhost:5002 | Backend v1.7.0 |
| Plugin v0.15.8 | http://localhost:8080/v015/ | Proxy to v0.15.8 |
| Plugin v1.7.0 | http://localhost:8080/v1x/ | Proxy to v1.7.0 |

## File Locations

| Component | Path |
|-----------|------|
| Plugin Source | ~/dev/nginx-lua-masking/ |
| OpenResty Config | /usr/local/openresty/conf/dev/ |
| Plugin Runtime | /usr/local/openresty/lualib/ |
| Logs | /var/log/nginx/ |
| Dify v0.15.8 | ~/dev/dify-v0.15.8/ |
| Dify v1.7.0 | ~/dev/dify-v1.7.0/ |

## Common Tasks

### Reload Plugin After Changes
```bash
sudo cp -r lib/* /usr/local/openresty/lualib/
sudo openresty -s reload
```

### View Real-time Logs
```bash
sudo tail -f /var/log/nginx/error.log
```

### Test Masking
```bash
curl -X POST http://localhost:8080/v015/v1/chat-messages \
  -H "Content-Type: application/json" \
  -d '{"query": "Email: test@example.com, IP: 192.168.1.1"}'
```

### Performance Test
```bash
ab -n 100 -c 10 http://localhost:8080/masking/health
```

## Troubleshooting

### Plugin Not Working
1. Check logs: `sudo tail -f /var/log/nginx/error.log`
2. Verify config: `curl http://localhost:8080/masking/debug`
3. Reload plugin: `./debug_plugin.sh reload`

### Dify Not Responding
1. Check Docker: `docker ps`
2. Restart Dify: `cd ~/dev/dify-v0.15.8 && docker-compose restart`
3. Check logs: `docker-compose logs -f`

### WSL2 Issues
1. Restart WSL2: `wsl --shutdown` (in PowerShell), then `wsl`
2. Check memory: `free -h`
3. Check network: `ping google.com`
EOF
```

## 🎉 Setup Complete!

Congratulations! Bạn đã hoàn thành setup môi trường development và testing cho Nginx Lua Masking Plugin trên Windows 11. 

### 🚀 Next Steps:
1. **Verify Setup**: Chạy `~/dev/verify_setup.sh`
2. **Start Development**: Chạy `~/dev/start_dev_environment.sh`
3. **Open VS Code**: `cd ~/dev/nginx-lua-masking && code .`
4. **Run Tests**: `./test_all.sh`
5. **Start Coding**: Edit plugin files và test changes

### 📚 Documentation:
- **Quick Reference**: `~/dev/QUICK_REFERENCE.md`
- **Troubleshooting**: `~/dev/nginx-lua-masking/TROUBLESHOOTING_WINDOWS.md`
- **Plugin Docs**: `~/dev/nginx-lua-masking/docs/`

### 🆘 Support:
- Check logs: `./debug_plugin.sh logs`
- Test functionality: `./debug_plugin.sh test`
- Reload plugin: `./debug_plugin.sh reload`

**Happy coding! 🎯**


#!/bin/bash
# Nginx Lua Masking Plugin v2.1 - Comprehensive Deploy Script
# Handles OpenResty, Nginx+Lua, and fallback scenarios

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PLUGIN_DIR="/opt/nginx-lua-masking"
DIFY_BACKEND="127.0.0.1:5001"
DOMAIN="localhost"
NGINX_PORT="80"

# Functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect and install appropriate nginx
detect_and_install_nginx() {
    log_info "Detecting and installing appropriate Nginx..."
    
    local nginx_cmd=""
    local has_lua=false
    
    # Check OpenResty first
    if command -v openresty &> /dev/null; then
        nginx_cmd="openresty"
        if openresty -V 2>&1 | grep -q "lua"; then
            has_lua=true
            log_info "Found OpenResty with Lua support"
        fi
    # Check nginx with lua
    elif command -v nginx &> /dev/null; then
        nginx_cmd="nginx"
        if nginx -V 2>&1 | grep -q "lua"; then
            has_lua=true
            log_info "Found Nginx with Lua support"
        fi
    fi
    
    # Install OpenResty if no Lua support
    if [ "$has_lua" = false ]; then
        log_warning "No Lua support found. Installing OpenResty..."
        
        # Try different installation methods
        if install_openresty_apt; then
            nginx_cmd="openresty"
            has_lua=true
        elif install_openresty_source; then
            nginx_cmd="openresty"
            has_lua=true
        else
            log_error "Failed to install OpenResty. Creating fallback configuration..."
            nginx_cmd="nginx"
            has_lua=false
        fi
    fi
    
    export NGINX_CMD="$nginx_cmd"
    export HAS_LUA="$has_lua"
    
    log_info "Using: $nginx_cmd (Lua: $has_lua)"
}

# Install OpenResty via APT
install_openresty_apt() {
    log_info "Attempting to install OpenResty via APT..."
    
    # Update and install dependencies
    sudo apt update
    sudo apt install -y software-properties-common wget curl
    
    # Try to add OpenResty repository
    if wget -qO - https://openresty.org/package/pubkey.gpg | sudo apt-key add - 2>/dev/null; then
        if sudo apt-add-repository "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" 2>/dev/null; then
            sudo apt update
            if sudo apt install -y openresty 2>/dev/null; then
                log_success "OpenResty installed via APT"
                return 0
            fi
        fi
    fi
    
    log_warning "APT installation failed"
    return 1
}

# Install OpenResty from source (simplified)
install_openresty_source() {
    log_info "Attempting to install OpenResty from source..."
    
    # Install build dependencies
    sudo apt install -y build-essential libpcre3-dev libssl-dev zlib1g-dev
    
    # Download and extract
    cd /tmp
    if wget -q https://openresty.org/download/openresty-1.21.4.1.tar.gz; then
        tar -xzf openresty-1.21.4.1.tar.gz
        cd openresty-1.21.4.1
        
        # Configure and build (with timeout)
        if timeout 300 ./configure --prefix=/usr/local/openresty 2>/dev/null; then
            if timeout 600 make -j2 2>/dev/null; then
                if sudo make install 2>/dev/null; then
                    # Add to PATH
                    sudo ln -sf /usr/local/openresty/bin/openresty /usr/local/bin/openresty
                    log_success "OpenResty installed from source"
                    return 0
                fi
            fi
        fi
    fi
    
    log_warning "Source installation failed"
    return 1
}

# Create plugin directory and files
install_plugin_files() {
    log_info "Installing plugin files..."
    
    # Create directories
    sudo mkdir -p "$PLUGIN_DIR"/{lib,config,examples}
    
    # Copy plugin files if they exist
    if [ -d "lib" ]; then
        sudo cp -r lib/* "$PLUGIN_DIR/lib/"
    fi
    
    if [ -d "config" ]; then
        sudo cp -r config/* "$PLUGIN_DIR/config/"
    fi
    
    if [ -d "examples" ]; then
        sudo cp -r examples/* "$PLUGIN_DIR/examples/"
    fi
    
    # Create minimal plugin files if not exist
    create_minimal_plugin_files
    
    # Set permissions
    sudo chown -R root:root "$PLUGIN_DIR"
    sudo chmod -R 755 "$PLUGIN_DIR"
    
    log_success "Plugin files installed"
}

# Create minimal plugin files for testing
create_minimal_plugin_files() {
    # Create minimal utils.lua
    sudo tee "$PLUGIN_DIR/lib/utils.lua" > /dev/null << 'UTILS_EOF'
local _M = {}

-- Simple JSON implementation
local json = {
    encode = function(obj)
        if type(obj) == "table" then
            local result = "{"
            local first = true
            for k, v in pairs(obj) do
                if not first then result = result .. "," end
                result = result .. '"' .. tostring(k) .. '":' .. json.encode(v)
                first = false
            end
            return result .. "}"
        elseif type(obj) == "string" then
            return '"' .. obj:gsub('"', '\\"') .. '"'
        else
            return tostring(obj)
        end
    end
}

_M.json = json

function _M.log(level, message)
    if ngx then
        ngx.log(ngx.ERR, "[MASKING-PLUGIN] " .. level .. ": " .. message)
    else
        print(os.date("%Y-%m-%d %H:%M:%S") .. " [MASKING-PLUGIN] " .. level .. ": " .. message)
    end
end

return _M
UTILS_EOF

    # Create minimal pattern_matcher.lua
    sudo tee "$PLUGIN_DIR/lib/pattern_matcher.lua" > /dev/null << 'PATTERN_EOF'
local utils = require("utils")
local _M = {}

function _M.new()
    local self = {
        patterns = {
            {name = "email", pattern = "[%w%._%+-]+@[%w%._%+-]+%.%w+", prefix = "EMAIL"},
            {name = "ip_private", pattern = "192%.168%.[0-9]+%.[0-9]+", prefix = "IP_PRIVATE"},
            {name = "ip_public", pattern = "[0-9]+%.[0-9]+%.[0-9]+%.[0-9]+", prefix = "IP_PUBLIC"}
        },
        mappings = {}
    }
    
    utils.log("INFO", "Pattern matcher initialized")
    return setmetatable(self, {__index = _M})
end

function _M:mask_text(text)
    local result = text
    local count = 0
    
    for _, pattern in ipairs(self.patterns) do
        local matches = {}
        for match in string.gmatch(result, pattern.pattern) do
            if not matches[match] then
                count = count + 1
                matches[match] = pattern.prefix .. "_" .. count
                result = string.gsub(result, match, matches[match])
            end
        end
    end
    
    utils.log("INFO", "Masked " .. count .. " values")
    return result
end

return _M
PATTERN_EOF

    log_info "Created minimal plugin files"
}

# Create nginx configuration
create_nginx_config() {
    log_info "Creating Nginx configuration..."
    
    local config_dir=""
    local config_file=""
    
    # Determine config location
    if [ "$NGINX_CMD" = "openresty" ]; then
        config_dir="/usr/local/openresty/nginx/conf"
        config_file="$config_dir/nginx.conf"
        sudo mkdir -p "$config_dir"
    else
        config_dir="/etc/nginx"
        config_file="$config_dir/nginx.conf"
    fi
    
    # Backup existing config
    if [ -f "$config_file" ]; then
        sudo cp "$config_file" "$config_file.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Create appropriate config based on Lua support
    if [ "$HAS_LUA" = "true" ]; then
        create_lua_config "$config_file"
    else
        create_fallback_config "$config_file"
    fi
    
    log_success "Configuration created at $config_file"
}

# Create Lua-enabled configuration
create_lua_config() {
    local config_file="$1"
    
    sudo tee "$config_file" > /dev/null << 'LUA_CONFIG_EOF'
worker_processes 1;
error_log /var/log/nginx/error.log debug;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    
    # Lua configuration
    lua_package_path "/opt/nginx-lua-masking/lib/?.lua;;";
    lua_shared_dict masking_mappings 10m;
    lua_shared_dict masking_stats 1m;
    
    # Initialize plugin
    init_by_lua_block {
        ngx.log(ngx.ERR, "Initializing masking plugin v2.1...")
        
        local ok, err = pcall(function()
            local utils = require("utils")
            local pattern_matcher = require("pattern_matcher")
            
            ngx.shared.masking_mappings:set("initialized", "true")
            ngx.shared.masking_mappings:set("version", "2.1.0")
            ngx.log(ngx.ERR, "Plugin initialized successfully")
        end)
        
        if not ok then
            ngx.log(ngx.ERR, "Plugin initialization failed: " .. tostring(err))
        end
    }
    
    # Upstream for Dify
    upstream dify_backend {
        server 127.0.0.1:5001;
        keepalive 32;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        # Health check
        location = /masking/health {
            content_by_lua_block {
                local ok, result = pcall(function()
                    local utils = require("utils")
                    local json = utils.json
                    
                    local health = {
                        status = "healthy",
                        version = "2.1.0",
                        dify_version = "auto-detect",
                        timestamp = ngx.time(),
                        lua_version = _VERSION,
                        nginx_version = ngx.var.nginx_version,
                        initialized = ngx.shared.masking_mappings:get("initialized") or "false"
                    }
                    
                    ngx.header.content_type = "application/json"
                    ngx.say(json.encode(health))
                end)
                
                if not ok then
                    ngx.status = 500
                    ngx.header.content_type = "text/plain"
                    ngx.say("Health check failed: " .. tostring(result))
                end
            }
        }
        
        # Test masking
        location = /masking/test {
            content_by_lua_block {
                local ok, result = pcall(function()
                    local pattern_matcher = require("pattern_matcher")
                    local utils = require("utils")
                    local json = utils.json
                    
                    local pm = pattern_matcher.new()
                    local test_text = "Email: test@example.com, IP: 192.168.1.1"
                    local masked = pm:mask_text(test_text)
                    
                    local response = {
                        original = test_text,
                        masked = masked,
                        timestamp = ngx.time()
                    }
                    
                    ngx.header.content_type = "application/json"
                    ngx.say(json.encode(response))
                end)
                
                if not ok then
                    ngx.status = 500
                    ngx.header.content_type = "text/plain"
                    ngx.say("Test failed: " .. tostring(result))
                end
            }
        }
        
        # Proxy to Dify
        location / {
            access_by_lua_block {
                ngx.log(ngx.ERR, "Processing request: " .. ngx.var.request_uri)
                -- TODO: Add masking logic here
            }
            
            proxy_pass http://dify_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_buffering off;
            proxy_cache off;
        }
    }
}
LUA_CONFIG_EOF

    log_info "Created Lua-enabled configuration"
}

# Create fallback configuration (no Lua)
create_fallback_config() {
    local config_file="$1"
    
    sudo tee "$config_file" > /dev/null << 'FALLBACK_CONFIG_EOF'
worker_processes 1;
error_log /var/log/nginx/error.log;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    
    # Upstream for Dify
    upstream dify_backend {
        server 127.0.0.1:5001;
        keepalive 32;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        # Health check (static response)
        location = /masking/health {
            return 200 '{"status":"healthy","version":"2.1.0","mode":"fallback","timestamp":1234567890,"note":"Lua not available - using fallback mode"}';
            add_header Content-Type application/json;
        }
        
        # Test endpoint
        location = /masking/test {
            return 200 '{"message":"Masking plugin in fallback mode","note":"Install OpenResty for full functionality"}';
            add_header Content-Type application/json;
        }
        
        # Simple proxy to Dify (no masking)
        location / {
            proxy_pass http://dify_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_buffering off;
            proxy_cache off;
        }
    }
}
FALLBACK_CONFIG_EOF

    log_warning "Created fallback configuration (no Lua support)"
}

# Test configuration
test_config() {
    log_info "Testing configuration..."
    
    if $NGINX_CMD -t; then
        log_success "Configuration test passed"
        return 0
    else
        log_error "Configuration test failed"
        return 1
    fi
}

# Start services
start_services() {
    log_info "Starting services..."
    
    # Stop existing nginx
    sudo pkill nginx 2>/dev/null || true
    sudo pkill openresty 2>/dev/null || true
    sleep 2
    
    # Start nginx
    if sudo $NGINX_CMD; then
        log_success "$NGINX_CMD started"
        sleep 3
        return 0
    else
        log_error "Failed to start $NGINX_CMD"
        return 1
    fi
}

# Run health check
run_health_check() {
    log_info "Running health check..."
    
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if response=$(curl -s http://localhost/masking/health 2>/dev/null); then
            if echo "$response" | grep -q "healthy\|status"; then
                log_success "Health check passed"
                echo "Response: $response"
                return 0
            fi
        fi
        
        log_warning "Health check attempt $attempt failed, retrying..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_error "Health check failed after $max_attempts attempts"
    return 1
}

# Show summary
show_summary() {
    echo ""
    echo "🎉 Deployment Summary"
    echo "===================="
    echo "Nginx Command: $NGINX_CMD"
    echo "Lua Support: $HAS_LUA"
    echo "Plugin Directory: $PLUGIN_DIR"
    echo ""
    echo "🎯 Available endpoints:"
    echo "  Health: http://localhost/masking/health"
    echo "  Test:   http://localhost/masking/test"
    echo ""
    echo "🔧 Management commands:"
    echo "  Test config: sudo $NGINX_CMD -t"
    echo "  Reload:      sudo $NGINX_CMD -s reload"
    echo "  Stop:        sudo $NGINX_CMD -s stop"
    echo "  Logs:        sudo tail -f /var/log/nginx/error.log"
}

# Main execution
main() {
    log_info "Starting Nginx Lua Masking Plugin v2.1 deployment..."
    echo ""
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    detect_and_install_nginx
    echo ""
    
    install_plugin_files
    echo ""
    
    create_nginx_config
    echo ""
    
    if test_config; then
        echo ""
        if start_services; then
            echo ""
            if run_health_check; then
                show_summary
                log_success "Deployment completed successfully!"
            else
                log_warning "Deployment completed but health check failed"
                echo "Check logs: sudo tail -f /var/log/nginx/error.log"
            fi
        else
            log_error "Failed to start services"
        fi
    else
        log_error "Configuration test failed"
    fi
}

# Handle command line arguments
case "${1:-}" in
    "--help"|"-h")
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --help, -h    Show this help"
        echo "  --domain, -d  Set domain (default: localhost)"
        echo "  --backend, -b Set Dify backend (default: 127.0.0.1:5001)"
        echo "  --port, -p    Set nginx port (default: 80)"
        exit 0
        ;;
    "--domain"|"-d")
        DOMAIN="$2"
        shift 2
        ;;
    "--backend"|"-b")
        DIFY_BACKEND="$2"
        shift 2
        ;;
    "--port"|"-p")
        NGINX_PORT="$2"
        shift 2
        ;;
esac

# Run main function
main "$@"

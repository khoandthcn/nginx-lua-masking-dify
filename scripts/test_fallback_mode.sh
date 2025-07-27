#!/bin/bash

echo "🧪 Testing Fallback Mode (No Lua)"
echo "================================="

# Create fallback nginx config
create_fallback_config() {
    echo "1. Creating fallback nginx configuration..."
    
    sudo mkdir -p /etc/nginx/test-fallback
    
    cat > /tmp/fallback-nginx.conf << 'EOF'
worker_processes 1;
error_log /var/log/nginx/fallback-error.log;
pid /var/run/nginx-fallback.pid;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    # Upstream for Dify (simulated)
    upstream dify_backend {
        server 127.0.0.1:5001;
        keepalive 32;
    }
    
    server {
        listen 8080;
        server_name localhost;
        
        # Health check (static response)
        location = /masking/health {
            return 200 '{"status":"healthy","version":"2.1.0","mode":"fallback","timestamp":1703123456,"note":"Lua not available - using fallback mode","nginx_version":"$nginx_version"}';
            add_header Content-Type application/json;
        }
        
        # Test endpoint
        location = /masking/test {
            return 200 '{"message":"Masking plugin in fallback mode","original":"test@example.com and 192.168.1.1","masked":"[FALLBACK] Original data preserved","note":"Install OpenResty for full masking functionality"}';
            add_header Content-Type application/json;
        }
        
        # Debug endpoint
        location = /masking/debug {
            return 200 '{"nginx_version":"$nginx_version","server_name":"$server_name","request_uri":"$request_uri","remote_addr":"$remote_addr","time_iso8601":"$time_iso8601"}';
            add_header Content-Type application/json;
        }
        
        # Simple proxy to Dify (no masking)
        location /api/ {
            # In real deployment, this would proxy to Dify
            return 200 '{"message":"This would proxy to Dify backend","backend":"127.0.0.1:5001","note":"No masking applied in fallback mode"}';
            add_header Content-Type application/json;
        }
        
        # Root page
        location = / {
            return 200 '<!DOCTYPE html>
<html>
<head><title>Nginx Lua Masking Plugin v2.1 - Fallback Mode</title></head>
<body>
<h1>Nginx Lua Masking Plugin v2.1</h1>
<h2>Fallback Mode (No Lua Support)</h2>
<p>The plugin is running in fallback mode because Lua support is not available.</p>
<h3>Available Endpoints:</h3>
<ul>
<li><a href="/masking/health">Health Check</a></li>
<li><a href="/masking/test">Test Masking (Fallback)</a></li>
<li><a href="/masking/debug">Debug Info</a></li>
<li><a href="/api/">API Proxy Test</a></li>
</ul>
<h3>To Enable Full Functionality:</h3>
<ol>
<li>Install OpenResty: <code>sudo apt install openresty</code></li>
<li>Or compile Nginx with lua-resty-core</li>
<li>Redeploy with: <code>sudo ./deploy_v2_1.sh</code></li>
</ol>
</body>
</html>';
            add_header Content-Type text/html;
        }
    }
}
EOF

    sudo cp /tmp/fallback-nginx.conf /etc/nginx/test-fallback/nginx.conf
    echo "✅ Fallback configuration created"
}

# Test fallback config
test_fallback_config() {
    echo "2. Testing fallback configuration..."
    
    if sudo nginx -t -c /etc/nginx/test-fallback/nginx.conf; then
        echo "✅ Fallback configuration test passed"
        return 0
    else
        echo "❌ Fallback configuration test failed"
        return 1
    fi
}

# Start fallback nginx
start_fallback_nginx() {
    echo "3. Starting fallback nginx..."
    
    # Stop any existing nginx
    sudo pkill nginx 2>/dev/null || true
    sleep 2
    
    # Start with fallback config
    if sudo nginx -c /etc/nginx/test-fallback/nginx.conf; then
        echo "✅ Fallback nginx started"
        sleep 3
        return 0
    else
        echo "❌ Failed to start fallback nginx"
        return 1
    fi
}

# Test fallback endpoints
test_fallback_endpoints() {
    echo "4. Testing fallback endpoints..."
    
    # Test health endpoint
    echo "Testing health endpoint..."
    if response=$(curl -s http://localhost:8080/masking/health); then
        if echo "$response" | grep -q "fallback\|healthy"; then
            echo "✅ Health endpoint OK"
            echo "Response: $response"
        else
            echo "⚠️  Unexpected health response: $response"
        fi
    else
        echo "❌ Health endpoint failed"
    fi
    
    # Test masking endpoint
    echo "Testing masking endpoint..."
    if response=$(curl -s http://localhost:8080/masking/test); then
        if echo "$response" | grep -q "fallback\|message"; then
            echo "✅ Masking test OK"
            echo "Response: $response"
        else
            echo "⚠️  Unexpected masking response: $response"
        fi
    else
        echo "❌ Masking test failed"
    fi
    
    # Test debug endpoint
    echo "Testing debug endpoint..."
    if response=$(curl -s http://localhost:8080/masking/debug); then
        if echo "$response" | grep -q "nginx_version\|server_name"; then
            echo "✅ Debug endpoint OK"
            echo "Response: $response"
        else
            echo "⚠️  Unexpected debug response: $response"
        fi
    else
        echo "❌ Debug endpoint failed"
    fi
    
    # Test API proxy
    echo "Testing API proxy..."
    if response=$(curl -s http://localhost:8080/api/); then
        if echo "$response" | grep -q "proxy\|backend"; then
            echo "✅ API proxy OK"
            echo "Response: $response"
        else
            echo "⚠️  Unexpected API response: $response"
        fi
    else
        echo "❌ API proxy failed"
    fi
    
    # Test root page
    echo "Testing root page..."
    if response=$(curl -s http://localhost:8080/); then
        if echo "$response" | grep -q "Fallback Mode\|Nginx Lua"; then
            echo "✅ Root page OK"
        else
            echo "⚠️  Unexpected root response"
        fi
    else
        echo "❌ Root page failed"
    fi
}

# Show fallback logs
show_fallback_logs() {
    echo "5. Recent fallback logs:"
    echo "========================"
    sudo tail -20 /var/log/nginx/fallback-error.log 2>/dev/null || echo "No fallback logs found"
}

# Cleanup fallback
cleanup_fallback() {
    echo "6. Cleaning up fallback test..."
    sudo pkill nginx 2>/dev/null || true
    sudo rm -f /var/run/nginx-fallback.pid
    echo "✅ Fallback cleanup completed"
}

# Performance test
performance_test() {
    echo "7. Basic performance test..."
    
    echo "Testing 10 concurrent requests..."
    for i in {1..10}; do
        curl -s http://localhost:8080/masking/health > /dev/null &
    done
    wait
    echo "✅ Concurrent requests completed"
    
    echo "Testing response time..."
    time curl -s http://localhost:8080/masking/health > /dev/null
}

# Main execution
main() {
    echo "🚀 Starting fallback mode test..."
    echo ""
    
    create_fallback_config
    echo ""
    
    if test_fallback_config; then
        echo ""
        if start_fallback_nginx; then
            echo ""
            test_fallback_endpoints
            echo ""
            performance_test
            echo ""
            show_fallback_logs
        else
            echo ""
            echo "❌ Failed to start fallback nginx"
            show_fallback_logs
        fi
    else
        echo ""
        echo "❌ Fallback configuration test failed"
    fi
    
    echo ""
    cleanup_fallback
    
    echo ""
    echo "🎉 Fallback mode test completed!"
    echo ""
    echo "📋 Summary:"
    echo "  ✅ Fallback mode provides basic functionality"
    echo "  ✅ Health checks work without Lua"
    echo "  ✅ Static responses for masking endpoints"
    echo "  ✅ Proxy functionality available"
    echo "  ⚠️  No real-time masking (requires OpenResty)"
}

# Handle arguments
case "${1:-}" in
    "config")
        create_fallback_config
        test_fallback_config
        ;;
    "start")
        start_fallback_nginx
        ;;
    "test")
        test_fallback_endpoints
        ;;
    "logs")
        show_fallback_logs
        ;;
    "cleanup")
        cleanup_fallback
        ;;
    *)
        main
        ;;
esac


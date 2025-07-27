#!/bin/bash

echo "🧪 Testing Deployment v2.1"
echo "=========================="

# Test endpoints
test_endpoints() {
    echo "Testing endpoints..."
    
    # Test health
    echo -n "Health endpoint: "
    if response=$(curl -s http://localhost/masking/health 2>/dev/null); then
        if echo "$response" | grep -q "healthy\|status"; then
            echo "✅ OK"
            echo "  Response: $response"
        else
            echo "⚠️  Unexpected: $response"
        fi
    else
        echo "❌ FAILED"
    fi
    
    # Test masking
    echo -n "Test endpoint: "
    if response=$(curl -s http://localhost/masking/test 2>/dev/null); then
        if echo "$response" | grep -q "masked\|message"; then
            echo "✅ OK"
            echo "  Response: $response"
        else
            echo "⚠️  Unexpected: $response"
        fi
    else
        echo "❌ FAILED"
    fi
}

# Check nginx status
check_nginx() {
    echo "Checking nginx status..."
    
    if pgrep nginx > /dev/null; then
        echo "✅ Nginx is running"
        ps aux | grep nginx | grep -v grep
    else
        echo "❌ Nginx is not running"
    fi
}

# Show logs
show_logs() {
    echo "Recent error logs:"
    echo "=================="
    sudo tail -20 /var/log/nginx/error.log 2>/dev/null || echo "No logs found"
}

# Main test
main() {
    check_nginx
    echo ""
    test_endpoints
    echo ""
    show_logs
}

main

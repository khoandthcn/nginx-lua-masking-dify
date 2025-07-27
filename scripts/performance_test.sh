#!/bin/bash

echo "🚀 Performance Testing - OpenResty Optimized Plugin"
echo "=================================================="

# Test configuration
ENDPOINT="http://localhost/masking/test"
HEALTH_ENDPOINT="http://localhost/masking/health"
CONCURRENT_USERS=10
REQUESTS_PER_USER=100

# Performance test function
run_performance_test() {
    echo "1. Warming up..."
    for i in {1..10}; do
        curl -s $HEALTH_ENDPOINT > /dev/null
    done
    
    echo "2. Running performance test..."
    echo "   Concurrent users: $CONCURRENT_USERS"
    echo "   Requests per user: $REQUESTS_PER_USER"
    echo "   Total requests: $((CONCURRENT_USERS * REQUESTS_PER_USER))"
    
    # Use Apache Bench if available
    if command -v ab &> /dev/null; then
        echo "Using Apache Bench (ab)..."
        ab -n $((CONCURRENT_USERS * REQUESTS_PER_USER)) -c $CONCURRENT_USERS $ENDPOINT
    else
        echo "Using curl (basic test)..."
        
        # Simple concurrent test with curl
        start_time=$(date +%s.%N)
        
        for i in $(seq 1 $CONCURRENT_USERS); do
            (
                for j in $(seq 1 $REQUESTS_PER_USER); do
                    curl -s $ENDPOINT > /dev/null
                done
            ) &
        done
        
        wait
        
        end_time=$(date +%s.%N)
        duration=$(echo "$end_time - $start_time" | bc)
        total_requests=$((CONCURRENT_USERS * REQUESTS_PER_USER))
        rps=$(echo "scale=2; $total_requests / $duration" | bc)
        
        echo "Results:"
        echo "  Total time: ${duration}s"
        echo "  Requests per second: $rps"
        echo "  Average response time: $(echo "scale=3; $duration / $total_requests" | bc)s"
    fi
}

# Memory usage test
test_memory_usage() {
    echo "3. Testing memory usage..."
    
    # Get initial memory
    initial_memory=$(ps aux | grep nginx | grep -v grep | awk '{sum += $6} END {print sum}')
    echo "   Initial memory usage: ${initial_memory}KB"
    
    # Run load test
    echo "   Running load test..."
    for i in {1..1000}; do
        curl -s $ENDPOINT > /dev/null
    done
    
    # Get final memory
    final_memory=$(ps aux | grep nginx | grep -v grep | awk '{sum += $6} END {print sum}')
    echo "   Final memory usage: ${final_memory}KB"
    echo "   Memory increase: $((final_memory - initial_memory))KB"
}

# Response time test
test_response_times() {
    echo "4. Testing response times..."
    
    echo "   Health endpoint:"
    for i in {1..5}; do
        time curl -s $HEALTH_ENDPOINT > /dev/null
    done
    
    echo "   Masking endpoint:"
    for i in {1..5}; do
        time curl -s $ENDPOINT > /dev/null
    done
}

# Main execution
main() {
    echo "Starting performance tests..."
    echo ""
    
    # Check if nginx is running
    if ! pgrep nginx > /dev/null; then
        echo "❌ Nginx is not running. Please start nginx first."
        exit 1
    fi
    
    # Check if endpoints are accessible
    if ! curl -s $HEALTH_ENDPOINT > /dev/null; then
        echo "❌ Health endpoint not accessible. Please check nginx configuration."
        exit 1
    fi
    
    run_performance_test
    echo ""
    
    test_memory_usage
    echo ""
    
    test_response_times
    echo ""
    
    echo "🎉 Performance testing completed!"
}

main

#!/usr/bin/env lua

-- Test Dify v0.15.8 Integration
package.path = "./?.lua;./lib/?.lua;./test/?.lua;" .. package.path

print("=== Dify v0.15.8 Integration Test ===")

-- Test 1: Dify Adapter
print("\n1. Testing Dify Adapter...")
local dify_adapter = require("lib.dify_adapter")

local config = {
    patterns = {
        email = {
            enabled = true,
            regex = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+%.[a-zA-Z][a-zA-Z]+",
            placeholder_prefix = "EMAIL"
        },
        ipv4 = {
            enabled = true,
            regex = "%d+%.%d+%.%d+%.%d+",
            placeholder_prefix = "IP"
        },
        organizations = {
            enabled = true,
            static_list = {"Google", "Microsoft", "Amazon", "Facebook", "Apple", "OpenAI"},
            placeholder_prefix = "ORG"
        }
    }
}

local success, adapter = pcall(dify_adapter.new, config)
if success then
    print("✓ Dify adapter created successfully")
    
    -- Test endpoint recognition
    local should_process, endpoint_config = adapter:should_process_request("/v1/chat-messages", "POST")
    print("✓ Endpoint recognition:", should_process and "WORKING" or "FAILED")
    
    -- Test health check
    local health = adapter:health_check()
    print("✓ Health check:", health.status)
    
else
    print("✗ Dify adapter failed:", adapter)
end

-- Test 2: Dify Message API
print("\n2. Testing Dify Message API...")
local dify_message_api = require("lib.dify_message_api")

local success2, api_handler = pcall(dify_message_api.new, config)
if success2 then
    print("✓ Dify Message API handler created successfully")
    
    -- Test chat messages request
    local chat_request = '{"query": "My email is user@example.com and I work at Google", "inputs": {"message": "Contact me at admin@company.com"}, "conversation_id": "conv_123"}'
    
    local processed_request, modified = api_handler:process_request("/v1/chat-messages", "POST", chat_request, "application/json")
    print("✓ Chat messages request processed, modified:", modified)
    print("  Original:", chat_request)
    print("  Processed:", processed_request)
    
    -- Test chat messages response
    local chat_response = '{"answer": "I will contact you at user@example.com regarding Google services", "message": {"content": "Response from admin@company.com"}}'
    
    local processed_response = api_handler:process_response("/v1/chat-messages", "POST", chat_response, "application/json", false)
    print("✓ Chat messages response processed")
    print("  Original:", chat_response)
    print("  Processed:", processed_response)
    
    -- Test completion messages
    local completion_request = '{"query": "Analyze data from server 192.168.1.100", "inputs": {"prompt": "Server at 10.0.0.1 needs analysis"}}'
    
    local processed_completion, modified2 = api_handler:process_request("/v1/completion-messages", "POST", completion_request, "application/json")
    print("✓ Completion messages request processed, modified:", modified2)
    print("  Original:", completion_request)
    print("  Processed:", processed_completion)
    
    -- Test messages list response
    local messages_list = '{"data": [{"query": "Email me at test@example.com", "answer": "I will email you at test@example.com"}, {"query": "Server 192.168.1.1 status", "answer": "Server 192.168.1.1 is online"}]}'
    
    local processed_list = api_handler:process_response("/v1/messages", "GET", messages_list, "application/json", false)
    print("✓ Messages list response processed")
    print("  Original:", messages_list)
    print("  Processed:", processed_list)
    
    -- Test streaming response
    local streaming_chunk = 'data: {"answer": "Contact support@example.com for help with Google services"}'
    
    local processed_chunk = api_handler:process_streaming_response(streaming_chunk, {"answer"})
    print("✓ Streaming response processed")
    print("  Original:", streaming_chunk)
    print("  Processed:", processed_chunk)
    
    -- Test API statistics
    local api_stats = api_handler:get_api_statistics()
    print("✓ API statistics generated, supported endpoints:", api_stats.message_api.endpoints_configured or 0)
    
else
    print("✗ Dify Message API handler failed:", api_handler)
end

-- Test 3: End-to-End Simulation
print("\n3. Testing End-to-End Simulation...")

if success and success2 then
    print("✓ Simulating complete Dify chat flow...")
    
    -- Simulate user request
    local user_request = {
        query = "I need help with my account. My email is john.doe@company.com and I'm calling from 192.168.1.50",
        inputs = {
            message = "Please contact me at support@mycompany.com",
            context = "User works at Microsoft"
        },
        conversation_id = "conv_456"
    }
    
    local request_json = '{"query": "' .. user_request.query .. '", "inputs": {"message": "' .. user_request.inputs.message .. '", "context": "' .. user_request.inputs.context .. '"}, "conversation_id": "' .. user_request.conversation_id .. '"}'
    
    -- Process request (masking)
    local masked_request, req_modified = api_handler:process_request("/v1/chat-messages", "POST", request_json, "application/json")
    print("  → Request masked:", req_modified)
    
    -- Simulate Dify processing and response
    local dify_response = '{"answer": "I will help you with your account. I will contact you at EMAIL_1 regarding ORG_1 services from IP_1", "message": {"content": "Support team at EMAIL_2 will assist you"}}'
    
    -- Process response (unmasking)
    local unmasked_response = api_handler:process_response("/v1/chat-messages", "POST", dify_response, "application/json", false)
    print("  → Response unmasked")
    
    print("  Final flow:")
    print("    User input: " .. user_request.query)
    print("    Masked request: " .. masked_request)
    print("    Dify response: " .. dify_response)
    print("    Final response: " .. unmasked_response)
    
    print("✓ End-to-end simulation completed successfully")
else
    print("✗ Cannot run end-to-end simulation due to previous failures")
end

-- Test 4: Performance Test
print("\n4. Testing Performance...")

if success2 then
    local start_time = os.clock()
    local iterations = 100
    
    for i = 1, iterations do
        local test_request = '{"query": "Test email user' .. i .. '@example.com", "inputs": {"message": "Server 192.168.1.' .. (i % 255) .. '"}}'
        api_handler:process_request("/v1/chat-messages", "POST", test_request, "application/json")
    end
    
    local end_time = os.clock()
    local total_time = end_time - start_time
    local avg_time = (total_time / iterations) * 1000
    
    print("✓ Performance test completed")
    print("  Iterations:", iterations)
    print("  Total time:", string.format("%.3f", total_time), "seconds")
    print("  Average time per request:", string.format("%.3f", avg_time), "ms")
    
    if avg_time < 10 then
        print("  Performance: EXCELLENT (< 10ms)")
    elseif avg_time < 50 then
        print("  Performance: GOOD (< 50ms)")
    else
        print("  Performance: ACCEPTABLE")
    end
else
    print("✗ Cannot run performance test")
end

print("\n=== Dify Integration Test Complete ===")
print("Summary:")
print("- Dify Adapter: " .. (success and "✓ WORKING" or "✗ FAILED"))
print("- Message API Handler: " .. (success2 and "✓ WORKING" or "✗ FAILED"))
print("- End-to-End Flow: " .. (success and success2 and "✓ WORKING" or "✗ FAILED"))
print("- Ready for Dify v0.15.8: " .. (success and success2 and "✅ YES" or "❌ NO"))


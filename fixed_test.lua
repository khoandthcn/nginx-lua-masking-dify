#!/usr/bin/env lua

-- Fixed test for core functions
package.path = "./?.lua;./lib/?.lua;./test/?.lua;" .. package.path

print("=== Fixed Core Functions Test ===")

-- Test 1: Pattern Matcher
print("\n1. Testing Pattern Matcher...")
local pattern_matcher = require("lib.pattern_matcher")

local config = {
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
        static_list = {"Google", "Microsoft", "Amazon", "Facebook", "Apple"},
        placeholder_prefix = "ORG"
    }
}

local success, matcher = pcall(pattern_matcher.new, config)
if success then
    print("✓ Pattern matcher created successfully")
    
    -- Test email masking
    local test_email = "Contact support@example.com for help"
    local masked, mappings = matcher:mask_text(test_email)
    print("✓ Email masking:", test_email, "->", masked)
    
    -- Test IP masking
    local test_ip = "Server at 192.168.1.100 is down"
    local masked_ip, mappings_ip = matcher:mask_text(test_ip)
    print("✓ IP masking:", test_ip, "->", masked_ip)
    
    -- Test organization masking
    local test_org = "Google and Microsoft are competitors"
    local masked_org, mappings_org = matcher:mask_text(test_org)
    print("✓ Organization masking:", test_org, "->", masked_org)
    
    -- Test reverse mapping
    local unmasked = matcher:unmask_text(masked)
    print("✓ Reverse mapping:", masked, "->", unmasked)
    
else
    print("✗ Pattern matcher failed:", matcher)
end

-- Test 2: JSON Processor
print("\n2. Testing JSON Processor...")
local json_processor = require("lib.json_processor")

local success2, processor = pcall(json_processor.new, matcher, {
    paths = {"$.query", "$.inputs.message"}
})

if success2 then
    print("✓ JSON processor created successfully")
    
    -- Test JSON processing
    local test_json = '{"query": "Email me at test@example.com", "inputs": {"message": "Visit 192.168.1.1"}}'
    local processed = processor:process_request(test_json, "application/json")
    print("✓ JSON processing:", test_json)
    print("  Processed:", processed)
    
else
    print("✗ JSON processor failed:", processor)
end

-- Test 3: Masking Plugin
print("\n3. Testing Masking Plugin...")
local masking_plugin = require("lib.masking_plugin")

local success3, plugin = pcall(masking_plugin.new)
if success3 then
    print("✓ Masking plugin created successfully")
    
    -- Test request processing
    local request_body = '{"query": "Contact admin@company.com", "data": "Server 10.0.0.1"}'
    local processed_request = plugin:process_request(request_body, "application/json")
    print("✓ Request processing:", request_body)
    print("  Processed:", processed_request)
    
    -- Test response processing
    local response_body = processed_request
    local processed_response = plugin:process_response(response_body, "application/json")
    print("✓ Response processing:", response_body)
    print("  Processed:", processed_response)
    
else
    print("✗ Masking plugin failed:", plugin)
end

print("\n=== Core Functions Test Complete ===")
print("Summary:")
print("- Pattern Matcher: " .. (success and "✓ WORKING" or "✗ FAILED"))
print("- JSON Processor: " .. (success2 and "✓ WORKING" or "✗ FAILED"))  
print("- Masking Plugin: " .. (success3 and "✓ WORKING" or "✗ FAILED"))


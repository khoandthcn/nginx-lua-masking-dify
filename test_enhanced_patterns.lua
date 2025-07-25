#!/usr/bin/env lua

-- Test enhanced patterns: IP private/public, IPv6, domains, hostnames

-- Set up package path
package.path = "./lib/?.lua;;" .. package.path

local utils = require("lib.utils")
local pattern_matcher = require("lib.pattern_matcher")

-- Test data
local test_cases = {
    {
        name = "Private IPv4 Addresses",
        text = "Server at 192.168.1.100 and database at 10.0.0.50 with backup at 172.16.0.10",
        expected_patterns = {"IP_PRIVATE_1", "IP_PRIVATE_2", "IP_PRIVATE_3"}
    },
    {
        name = "Public IPv4 Addresses", 
        text = "Connect to 8.8.8.8 and 1.1.1.1 for DNS resolution",
        expected_patterns = {"IP_PUBLIC_1", "IP_PUBLIC_2"}
    },
    {
        name = "IPv6 Addresses",
        text = "IPv6 server at 2001:db8::1 and backup at fe80::1",
        expected_patterns = {"IPV6_1", "IPV6_2"}
    },
    {
        name = "Domain Names",
        text = "Visit google.com or microsoft.com for more info about openai.com services",
        expected_patterns = {"DOMAIN_1", "DOMAIN_2", "DOMAIN_3"}
    },
    {
        name = "Hostnames",
        text = "Check api server, www host, and database node for production environment",
        expected_patterns = {"HOSTNAME_1", "HOSTNAME_2", "HOSTNAME_3", "HOSTNAME_4"}
    },
    {
        name = "Mixed Content",
        text = "Email admin@google.com from server 192.168.1.1 about api.github.com issues at Microsoft",
        expected_patterns = {"EMAIL_1", "DOMAIN_1", "IP_PRIVATE_1", "HOSTNAME_1", "DOMAIN_2", "ORG_1"}
    },
    {
        name = "Case Insensitive Domains",
        text = "Visit GOOGLE.COM or Microsoft.com for information",
        expected_patterns = {"DOMAIN_1", "DOMAIN_2"}
    },
    {
        name = "Localhost and Development",
        text = "Connect to localhost:3000 and staging server for testing",
        expected_patterns = {"HOSTNAME_1", "HOSTNAME_2"}
    }
}

-- Initialize pattern matcher
print("=== Enhanced Pattern Matching Test ===")
print("Initializing pattern matcher...")

local matcher = pattern_matcher.new()
if not matcher then
    print("❌ Failed to initialize pattern matcher")
    os.exit(1)
end

print("✅ Pattern matcher initialized")
print("")

-- Run tests
local total_tests = 0
local passed_tests = 0

for _, test_case in ipairs(test_cases) do
    total_tests = total_tests + 1
    
    print("🧪 Testing: " .. test_case.name)
    print("  Input: " .. test_case.text)
    
    -- Mask the text
    local masked_text = matcher:mask_text(test_case.text)
    print("  Masked: " .. masked_text)
    
    -- Check if masking occurred
    local masking_occurred = masked_text ~= test_case.text
    
    if masking_occurred then
        print("  ✅ Masking applied")
        passed_tests = passed_tests + 1
    else
        print("  ❌ No masking applied")
    end
    
    -- Test reverse mapping
    local unmasked_text = matcher:unmask_text(masked_text)
    print("  Unmasked: " .. unmasked_text)
    
    if unmasked_text == test_case.text then
        print("  ✅ Reverse mapping successful")
    else
        print("  ❌ Reverse mapping failed")
        print("    Expected: " .. test_case.text)
        print("    Got: " .. unmasked_text)
    end
    
    print("")
end

-- Test specific IP validation
print("🧪 Testing IP Validation Functions")

local ip_tests = {
    {ip = "192.168.1.1", private = true, public = false, valid = true},
    {ip = "10.0.0.1", private = true, public = false, valid = true},
    {ip = "172.16.0.1", private = true, public = false, valid = true},
    {ip = "8.8.8.8", private = false, public = true, valid = true},
    {ip = "1.1.1.1", private = false, public = true, valid = true},
    {ip = "127.0.0.1", private = true, public = false, valid = true},
    {ip = "256.1.1.1", private = false, public = false, valid = false},
    {ip = "invalid", private = false, public = false, valid = false}
}

for _, test in ipairs(ip_tests) do
    local is_private = matcher:is_private_ipv4(test.ip)
    local is_public = matcher:is_public_ipv4(test.ip)
    
    print("  IP: " .. test.ip)
    print("    Private: " .. tostring(is_private) .. " (expected: " .. tostring(test.private) .. ")")
    print("    Public: " .. tostring(is_public) .. " (expected: " .. tostring(test.public) .. ")")
    
    if is_private == test.private and is_public == test.public then
        print("    ✅ Validation correct")
        passed_tests = passed_tests + 1
    else
        print("    ❌ Validation incorrect")
    end
    total_tests = total_tests + 1
end

-- Test IPv6 validation
print("")
print("🧪 Testing IPv6 Validation")

local ipv6_tests = {
    {ip = "2001:db8::1", valid = true},
    {ip = "fe80::1", valid = true},
    {ip = "::1", valid = true},
    {ip = "2001:0db8:85a3:0000:0000:8a2e:0370:7334", valid = true},
    {ip = "invalid:ipv6", valid = false},
    {ip = "192.168.1.1", valid = false},
    {ip = "", valid = false}
}

for _, test in ipairs(ipv6_tests) do
    local is_valid = matcher:is_valid_ipv6(test.ip)
    
    print("  IPv6: " .. test.ip)
    print("    Valid: " .. tostring(is_valid) .. " (expected: " .. tostring(test.valid) .. ")")
    
    if is_valid == test.valid then
        print("    ✅ Validation correct")
        passed_tests = passed_tests + 1
    else
        print("    ❌ Validation incorrect")
    end
    total_tests = total_tests + 1
end

-- Summary
print("")
print("=== Test Summary ===")
print("Total tests: " .. total_tests)
print("Passed tests: " .. passed_tests)
print("Failed tests: " .. (total_tests - passed_tests))
print("Success rate: " .. string.format("%.1f%%", (passed_tests / total_tests) * 100))

if passed_tests == total_tests then
    print("🎉 All tests passed!")
    os.exit(0)
else
    print("❌ Some tests failed")
    os.exit(1)
end


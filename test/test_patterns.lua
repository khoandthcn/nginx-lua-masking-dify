-- test_patterns.lua - Pattern matching tests for nginx-lua-masking plugin
-- Author: Manus AI
-- Version: 1.0.0

local test_runner = require("test.test_runner")
local pattern_matcher = require("lib.pattern_matcher")

describe("Pattern Matcher", function()
    local matcher
    
    setup(function()
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
        local success, result = pcall(pattern_matcher.new, config)
        if success then
            matcher = result
        else
            error("Failed to create pattern matcher: " .. tostring(result))
        end
    end)
    
    teardown(function()
        if matcher then
            matcher:clear_mappings()
        end
    end)
    
    before_each(function()
        if matcher then
            matcher:clear_mappings()
        end
    end)
    
    describe("Email Pattern Matching", function()
        it("should match valid email addresses", function()
            local text = "Contact us at support@example.com or admin@test.org"
            local result = matcher:mask_text(text)
            
            assert_not_equal(result, text)
            assert_match(result, "EMAIL_%d+")
        end)
        
        it("should handle multiple email addresses", function()
            local text = "Emails: user1@domain1.com, user2@domain2.org, admin@company.net"
            local result = matcher:mask_text(text)
            
            assert_match(result, "EMAIL_%d+")
            -- Should contain multiple different placeholders
            local email_count = 0
            for _ in result:gmatch("EMAIL_%d+") do
                email_count = email_count + 1
            end
            assert_equal(email_count, 3)
        end)
        
        it("should validate email format correctly", function()
            local invalid_emails = {
                "invalid-email",
                "user@",
                "@domain.com",
                "user@domain",
                "user@domain.",
                "user..name@domain.com"
            }
            
            for _, email in ipairs(invalid_emails) do
                local result = matcher:mask_text(email)
                assert_equal(result, email, "Should not mask invalid email: " .. email)
            end
        end)
        
        it("should handle edge cases", function()
            local text = "Email: user+tag@sub.domain.co.uk"
            local result = matcher:mask_text(text)
            assert_match(result, "EMAIL_%d+")
        end)
        
        it("should maintain consistency for same email", function()
            local text1 = "Email: test@example.com"
            local text2 = "Another email: test@example.com"
            
            local result1 = matcher:mask_text(text1)
            local result2 = matcher:mask_text(text2)
            
            local placeholder1 = result1:match("EMAIL_%d+")
            local placeholder2 = result2:match("EMAIL_%d+")
            
            assert_equal(placeholder1, placeholder2)
        end)
    end)
    
    describe("IPv4 Pattern Matching", function()
        it("should match valid IPv4 addresses", function()
            local text = "Server IP: 192.168.1.1 and backup: 10.0.0.1"
            local result = matcher:mask_text(text)
            
            assert_not_equal(result, text)
            assert_match(result, "IP_%d+")
        end)
        
        it("should validate IPv4 format correctly", function()
            local valid_ips = {"192.168.1.1", "10.0.0.1", "172.16.0.1", "8.8.8.8", "127.0.0.1"}
            
            for _, ip in ipairs(valid_ips) do
                local result = matcher:mask_text(ip)
                assert_match(result, "IP_%d+", "Should mask valid IP: " .. ip)
            end
        end)
        
        it("should reject invalid IPv4 addresses", function()
            local invalid_ips = {
                "256.256.256.256",
                "192.168.1",
                "192.168.1.1.1",
                "192.168.01.1",  -- leading zero
                "192.168.-1.1"   -- negative number
            }
            
            for _, ip in ipairs(invalid_ips) do
                local result = matcher:mask_text(ip)
                assert_equal(result, ip, "Should not mask invalid IP: " .. ip)
            end
        end)
        
        it("should handle multiple IP addresses", function()
            local text = "IPs: 192.168.1.1, 10.0.0.1, 172.16.0.1"
            local result = matcher:mask_text(text)
            
            local ip_count = 0
            for _ in result:gmatch("IP_%d+") do
                ip_count = ip_count + 1
            end
            assert_equal(ip_count, 3)
        end)
        
        it("should maintain consistency for same IP", function()
            local text1 = "IP: 192.168.1.1"
            local text2 = "Same IP: 192.168.1.1"
            
            local result1 = matcher:mask_text(text1)
            local result2 = matcher:mask_text(text2)
            
            local placeholder1 = result1:match("IP_%d+")
            local placeholder2 = result2:match("IP_%d+")
            
            assert_equal(placeholder1, placeholder2)
        end)
    end)
    
    describe("Organization Pattern Matching", function()
        it("should match organization names from static list", function()
            local text = "I work at Google and my friend works at Microsoft"
            local result = matcher:mask_text(text)
            
            assert_not_equal(result, text)
            assert_match(result, "ORG_%d+")
        end)
        
        it("should handle case sensitivity", function()
            local text = "Companies: google, MICROSOFT, Amazon"
            local result = matcher:mask_text(text)
            
            -- Should match regardless of case
            local org_count = 0
            for _ in result:gmatch("ORG_%d+") do
                org_count = org_count + 1
            end
            assert_true(org_count >= 2)  -- At least Amazon should match
        end)
        
        it("should match whole words only", function()
            local text = "Googled something and Microsoftware"
            local result = matcher:mask_text(text)
            
            -- Should not match partial words
            assert_equal(result, text)
        end)
        
        it("should handle multiple organizations", function()
            local text = "Tech giants: Google, Microsoft, Amazon, Apple, Facebook"
            local result = matcher:mask_text(text)
            
            local org_count = 0
            for _ in result:gmatch("ORG_%d+") do
                org_count = org_count + 1
            end
            assert_equal(org_count, 5)
        end)
        
        it("should maintain consistency for same organization", function()
            local text1 = "Company: Google"
            local text2 = "Another mention: Google"
            
            local result1 = matcher:mask_text(text1)
            local result2 = matcher:mask_text(text2)
            
            local placeholder1 = result1:match("ORG_%d+")
            local placeholder2 = result2:match("ORG_%d+")
            
            assert_equal(placeholder1, placeholder2)
        end)
    end)
    
    describe("Mixed Pattern Matching", function()
        it("should handle text with multiple pattern types", function()
            local text = "Contact support@google.com at Google HQ, server IP: 192.168.1.1"
            local result = matcher:mask_text(text)
            
            assert_match(result, "EMAIL_%d+")
            assert_match(result, "ORG_%d+")
            assert_match(result, "IP_%d+")
        end)
        
        it("should handle complex nested patterns", function()
            local text = "Email admin@microsoft.com from Microsoft server 10.0.0.1"
            local result = matcher:mask_text(text)
            
            -- Should mask all three patterns
            assert_match(result, "EMAIL_%d+")
            assert_match(result, "ORG_%d+")
            assert_match(result, "IP_%d+")
        end)
        
        it("should handle empty and nil input", function()
            assert_equal(matcher:mask_text(""), "")
            assert_equal(matcher:mask_text(nil), nil)
        end)
        
        it("should handle text without sensitive data", function()
            local text = "This is just regular text without any sensitive information"
            local result = matcher:mask_text(text)
            assert_equal(result, text)
        end)
    end)
    
    describe("Reverse Mapping (Unmasking)", function()
        it("should reverse map placeholders back to original values", function()
            local original = "Email: test@example.com, IP: 192.168.1.1, Company: Google"
            local masked = matcher:mask_text(original)
            local unmasked = matcher:unmask_text(masked)
            
            assert_equal(unmasked, original)
        end)
        
        it("should handle partial unmasking", function()
            local text = "Placeholder EMAIL_1 should be unmasked"
            -- First create a mapping
            matcher:mask_text("test@example.com")
            
            local result = matcher:unmask_text(text)
            assert_match(result, "test@example.com")
        end)
        
        it("should handle text without placeholders", function()
            local text = "Regular text without placeholders"
            local result = matcher:unmask_text(text)
            assert_equal(result, text)
        end)
        
        it("should handle empty and nil input for unmasking", function()
            assert_equal(matcher:unmask_text(""), "")
            assert_equal(matcher:unmask_text(nil), nil)
        end)
    end)
    
    describe("Statistics and Management", function()
        it("should provide accurate statistics", function()
            local text = "Email: test@example.com, IP: 192.168.1.1, Company: Google"
            matcher:mask_text(text)
            
            local stats = matcher:get_stats()
            assert_type(stats, "table")
            assert_type(stats.total_mappings, "number")
            assert_true(stats.total_mappings > 0)
        end)
        
        it("should clear mappings correctly", function()
            local text = "Email: test@example.com"
            matcher:mask_text(text)
            
            local stats_before = matcher:get_stats()
            assert_true(stats_before.total_mappings > 0)
            
            matcher:clear_mappings()
            
            local stats_after = matcher:get_stats()
            assert_equal(stats_after.total_mappings, 0)
        end)
        
        it("should export and import mappings", function()
            local text = "Email: test@example.com, Company: Google"
            matcher:mask_text(text)
            
            local exported = matcher:export_mappings()
            assert_type(exported, "table")
            
            matcher:clear_mappings()
            matcher:import_mappings(exported)
            
            local stats = matcher:get_stats()
            assert_true(stats.total_mappings > 0)
        end)
    end)
    
    describe("Pattern Testing", function()
        it("should test individual patterns", function()
            local success, matches = matcher:test_pattern("email", "Contact: test@example.com and admin@test.org")
            assert_true(success)
            assert_type(matches, "table")
            assert_equal(#matches, 2)
        end)
        
        it("should handle invalid pattern names", function()
            local success, error_msg = matcher:test_pattern("invalid_pattern", "test text")
            assert_false(success)
            assert_type(error_msg, "string")
        end)
        
        it("should test static list patterns", function()
            local success, matches = matcher:test_pattern("organizations", "I work at Google and Microsoft")
            assert_true(success)
            assert_type(matches, "table")
            assert_true(#matches >= 2)
        end)
    end)
end)


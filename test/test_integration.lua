-- test_integration.lua - Integration tests for nginx-lua-masking plugin
-- Author: Manus AI
-- Version: 1.0.0

local test_runner = require("test.test_runner")
local masking_plugin = require("lib.masking_plugin")

describe("Masking Plugin Integration", function()
    local plugin
    
    setup(function()
        local config = {
            enabled = true,
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
                    static_list = {"Google", "Microsoft", "Amazon", "Facebook", "Apple"},
                    placeholder_prefix = "ORG"
                }
            },
            json_paths = {
                "$.user.email",
                "$.server.ip",
                "$.company.name"
            }
        }
        local success, result = pcall(masking_plugin.new, config)
        if success then
            plugin = result
        else
            error("Failed to create plugin: " .. tostring(result))
        end
    end)
    
    teardown(function()
        if plugin then
            plugin:cleanup()
        end
    end)
    
    before_each(function()
        if plugin then
            plugin.pattern_matcher:clear_mappings()
        end
    end)
    
    describe("Plugin Initialization", function()
        it("should initialize plugin successfully", function()
            assert_not_nil(plugin)
            assert_true(plugin.enabled)
        end)
        
        it("should reject invalid configuration", function()
            local invalid_config = {
                patterns = "invalid"  -- should be table
            }
            local invalid_plugin, error_msg = masking_plugin.new(invalid_config)
            
            assert_nil(invalid_plugin)
            assert_type(error_msg, "string")
        end)
        
        it("should handle missing configuration", function()
            local default_plugin = masking_plugin.new()
            assert_not_nil(default_plugin)
            assert_true(default_plugin.enabled)
            default_plugin:cleanup()
        end)
    end)
    
    describe("End-to-End Request/Response Processing", function()
        it("should process complete request/response cycle", function()
            local request_body = '{"user": {"email": "john@example.com"}, "server": {"ip": "192.168.1.1"}, "company": {"name": "Google"}}'
            local content_type = "application/json"
            
            -- Process request
            local masked_request, modified = plugin:process_request(request_body, content_type, {})
            
            assert_true(modified)
            assert_not_equal(masked_request, request_body)
            assert_match(masked_request, "EMAIL_%d+")
            assert_match(masked_request, "IP_%d+")
            assert_match(masked_request, "ORG_%d+")
            
            -- Simulate response with same placeholders
            local response_body = masked_request
            local unmasked_response = plugin:process_response(response_body, content_type, {})
            
            -- Should get back original values
            assert_match(unmasked_response, "john@example.com")
            assert_match(unmasked_response, "192.168.1.1")
            assert_match(unmasked_response, "Google")
        end)
        
        it("should handle non-JSON requests", function()
            local request_body = "This is plain text"
            local content_type = "text/plain"
            
            local result, modified = plugin:process_request(request_body, content_type, {})
            
            assert_false(modified)
            assert_equal(result, request_body)
        end)
        
        it("should handle empty requests", function()
            local result, modified = plugin:process_request("", "application/json", {})
            
            assert_false(modified)
            assert_equal(result, "")
        end)
        
        it("should handle malformed JSON gracefully", function()
            local malformed_json = '{"user": {"email": "test@example.com"'  -- missing closing brace
            local result, modified = plugin:process_request(malformed_json, "application/json", {})
            
            assert_false(modified)
            assert_equal(result, malformed_json)
        end)
    end)
    
    describe("Stream Processing", function()
        it("should process response chunks", function()
            -- First create mappings
            local request = '{"user": {"email": "test@example.com"}}'
            plugin:process_request(request, "application/json", {})
            
            -- Process response in chunks
            local chunk1 = '{"user": {"email": "'
            local chunk2 = 'EMAIL_1'
            local chunk3 = '"}}'
            
            local result1 = plugin:process_response_chunk(chunk1, "application/json", false)
            local result2 = plugin:process_response_chunk(chunk2, "application/json", false)
            local result3 = plugin:process_response_chunk(chunk3, "application/json", true)
            
            local complete_response = result1 .. result2 .. result3
            assert_match(complete_response, "test@example.com")
        end)
        
        it("should handle large streaming responses", function()
            -- Create mappings
            plugin:process_request('{"user": {"email": "test@example.com"}}', "application/json", {})
            
            -- Simulate large streaming response
            local large_chunk = string.rep("EMAIL_1 ", 1000)  -- Repeat placeholder many times
            local result = plugin:process_response_chunk(large_chunk, "text/plain", true)
            
            assert_match(result, "test@example.com")
        end)
        
        it("should handle mixed content types in streaming", function()
            local json_chunk = '{"email": "EMAIL_1"}'
            local text_chunk = "Plain text with EMAIL_1"
            
            -- Create mapping first
            plugin:process_request('{"user": {"email": "test@example.com"}}', "application/json", {})
            
            local json_result = plugin:process_response_chunk(json_chunk, "application/json", false)
            local text_result = plugin:process_response_chunk(text_chunk, "text/plain", true)
            
            assert_match(json_result, "test@example.com")
            assert_match(text_result, "test@example.com")
        end)
    end)
    
    describe("Configuration Management", function()
        it("should update configuration at runtime", function()
            local new_config = {
                patterns = {
                    email = {
                        enabled = false  -- Disable email pattern
                    }
                }
            }
            
            local success, message = plugin:update_config(new_config)
            assert_true(success)
            assert_type(message, "string")
            
            -- Test that email pattern is now disabled
            local request = '{"user": {"email": "test@example.com"}}'
            local result, modified = plugin:process_request(request, "application/json", {})
            
            -- Should not mask email since it's disabled
            assert_match(result, "test@example.com")
        end)
        
        it("should reject invalid configuration updates", function()
            local invalid_config = {
                patterns = "invalid"
            }
            
            local success, message = plugin:update_config(invalid_config)
            assert_false(success)
            assert_type(message, "string")
        end)
        
        it("should enable/disable plugin", function()
            plugin:set_enabled(false)
            assert_false(plugin.enabled)
            
            local request = '{"user": {"email": "test@example.com"}}'
            local result, modified = plugin:process_request(request, "application/json", {})
            
            assert_false(modified)
            assert_equal(result, request)
            
            plugin:set_enabled(true)
            assert_true(plugin.enabled)
        end)
    end)
    
    describe("Statistics and Monitoring", function()
        it("should provide comprehensive statistics", function()
            -- Process some requests to generate stats
            local request = '{"user": {"email": "test@example.com"}, "server": {"ip": "192.168.1.1"}}'
            plugin:process_request(request, "application/json", {})
            
            local stats = plugin:get_stats()
            
            assert_type(stats, "table")
            assert_type(stats.plugin, "table")
            assert_type(stats.patterns, "table")
            assert_type(stats.json_processing, "table")
            
            assert_true(stats.plugin.total_requests > 0)
            assert_true(stats.patterns.total_mappings > 0)
        end)
        
        it("should track error statistics", function()
            local initial_stats = plugin:get_stats()
            local initial_errors = initial_stats.plugin.error_count
            
            -- Force an error by processing invalid data
            plugin.json_processor = nil  -- This will cause an error
            plugin:process_request('{"test": "data"}', "application/json", {})
            
            -- Restore json_processor
            local pattern_matcher = require("lib.pattern_matcher")
            local json_processor = require("lib.json_processor")
            plugin.json_processor = json_processor.new(pattern_matcher.new(plugin.config.patterns), plugin.config)
            
            local final_stats = plugin:get_stats()
            assert_true(final_stats.plugin.error_count > initial_errors)
        end)
        
        it("should provide health check information", function()
            local health = plugin:health_check()
            
            assert_type(health, "table")
            assert_type(health.status, "string")
            assert_type(health.timestamp, "number")
            assert_type(health.stats, "table")
        end)
        
        it("should detect unhealthy conditions", function()
            -- Disable plugin to trigger warning
            plugin:set_enabled(false)
            
            local health = plugin:health_check()
            assert_equal(health.status, "disabled")
            assert_true(#health.issues > 0)
            
            plugin:set_enabled(true)
        end)
    end)
    
    describe("Plugin Testing Framework", function()
        it("should test plugin functionality", function()
            local test_data = {
                request = '{"user": {"email": "test@example.com"}}',
                response = '{"user": {"email": "EMAIL_1"}}',
                patterns = {
                    email = "Contact us at support@example.com",
                    ipv4 = "Server IP is 192.168.1.1",
                    organizations = "I work at Google"
                }
            }
            
            local success, results = plugin:test(test_data)
            
            assert_true(success)
            assert_type(results, "table")
            assert_type(results.request_processing, "table")
            assert_type(results.response_processing, "table")
            assert_type(results.pattern_matching, "table")
        end)
        
        it("should handle test without data", function()
            local success, error_msg = plugin:test()
            
            assert_false(success)
            assert_type(error_msg, "string")
        end)
    end)
    
    describe("State Management", function()
        it("should export plugin state", function()
            local state = plugin:export_state()
            
            assert_type(state, "table")
            assert_type(state.config, "table")
            assert_type(state.stats, "table")
            assert_type(state.health, "table")
            assert_type(state.mappings, "table")
        end)
        
        it("should cleanup resources properly", function()
            local initial_mappings = plugin.pattern_matcher:get_stats().total_mappings
            
            -- Create some mappings
            plugin:process_request('{"user": {"email": "test@example.com"}}', "application/json", {})
            
            local after_processing = plugin.pattern_matcher:get_stats().total_mappings
            assert_true(after_processing > initial_mappings)
            
            -- Cleanup
            plugin:cleanup()
            
            local after_cleanup = plugin.pattern_matcher:get_stats().total_mappings
            assert_equal(after_cleanup, 0)
        end)
    end)
    
    describe("Performance and Scalability", function()
        it("should handle multiple concurrent-like requests", function()
            local requests = {
                '{"user1": {"email": "user1@test.com"}}',
                '{"user2": {"email": "user2@test.com"}}',
                '{"user3": {"email": "user3@test.com"}}'
            }
            
            local results = {}
            for i, request in ipairs(requests) do
                local result, modified = plugin:process_request(request, "application/json", {})
                results[i] = {result = result, modified = modified}
            end
            
            -- All should be processed successfully
            for i, result in ipairs(results) do
                assert_true(result.modified, "Request " .. i .. " should be modified")
                assert_match(result.result, "EMAIL_%d+", "Request " .. i .. " should contain placeholder")
            end
        end)
        
        it("should handle large payloads", function()
            -- Create a large JSON with many sensitive values
            local large_json = '{"users": ['
            for i = 1, 50 do
                if i > 1 then large_json = large_json .. ',' end
                large_json = large_json .. '{"id": ' .. i .. ', "email": "user' .. i .. '@test.com", "company": "Google"}'
            end
            large_json = large_json .. ']}'
            
            local start_time = os.clock()
            local result, modified = plugin:process_request(large_json, "application/json", {})
            local end_time = os.clock()
            
            assert_true(modified)
            assert_true(end_time - start_time < 1.0, "Processing should complete within 1 second")
            
            -- Count placeholders
            local email_count = 0
            local org_count = 0
            for _ in result:gmatch("EMAIL_%d+") do email_count = email_count + 1 end
            for _ in result:gmatch("ORG_%d+") do org_count = org_count + 1 end
            
            assert_equal(email_count, 50)
            assert_equal(org_count, 50)
        end)
        
        it("should maintain performance with many mappings", function()
            -- Create many mappings
            for i = 1, 100 do
                local request = '{"user": {"email": "user' .. i .. '@test.com"}}'
                plugin:process_request(request, "application/json", {})
            end
            
            -- Performance should still be good
            local start_time = os.clock()
            local request = '{"user": {"email": "newuser@test.com"}}'
            plugin:process_request(request, "application/json", {})
            local end_time = os.clock()
            
            assert_true(end_time - start_time < 0.1, "Processing should remain fast with many mappings")
        end)
    end)
    
    describe("Global Functions", function()
        it("should provide global cleanup functionality", function()
            local cleanup_result = masking_plugin.global_cleanup(0)  -- Cleanup all
            
            assert_type(cleanup_result, "table")
            assert_type(cleanup_result.cleaned_requests, "number")
            assert_type(cleanup_result.cleaned_mappings, "number")
        end)
        
        it("should provide global statistics", function()
            local global_stats = masking_plugin.global_stats()
            
            assert_type(global_stats, "table")
            assert_type(global_stats.total_requests_processed, "number")
            assert_type(global_stats.active_requests, "number")
            assert_type(global_stats.total_active_mappings, "number")
        end)
    end)
end)


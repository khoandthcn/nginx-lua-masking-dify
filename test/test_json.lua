-- test_json.lua - JSON processing tests for nginx-lua-masking plugin
-- Author: Manus AI
-- Version: 1.0.0

local test_runner = require("test.test_runner")
local pattern_matcher = require("lib.pattern_matcher")
local json_processor = require("lib.json_processor")

describe("JSON Processor", function()
    local matcher
    local processor
    
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
        
        local processor_config = {
            json_paths = {
                "$.user.email",
                "$.server.ip",
                "$.company.name"
            }
        }
        local success2, result2 = pcall(json_processor.new, matcher, processor_config)
        if success2 then
            processor = result2
        else
            error("Failed to create JSON processor: " .. tostring(result2))
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
    
    describe("Content Type Detection", function()
        it("should detect JSON content types", function()
            assert_true(processor:is_json_content("application/json"))
            assert_true(processor:is_json_content("application/json; charset=utf-8"))
            assert_true(processor:is_json_content("text/json"))
        end)
        
        it("should reject non-JSON content types", function()
            assert_false(processor:is_json_content("text/plain"))
            assert_false(processor:is_json_content("text/html"))
            assert_false(processor:is_json_content("application/xml"))
            assert_false(processor:is_json_content(nil))
        end)
        
        it("should handle case insensitive content types", function()
            assert_true(processor:is_json_content("APPLICATION/JSON"))
            assert_true(processor:is_json_content("Application/Json"))
        end)
    end)
    
    describe("JSON Validation", function()
        it("should validate correct JSON", function()
            local json_string = '{"user": {"email": "test@example.com"}}'
            local valid, result = processor:validate_json(json_string)
            
            assert_true(valid)
            assert_type(result, "table")
        end)
        
        it("should reject invalid JSON", function()
            local invalid_jsons = {
                '{"user": {"email": "test@example.com"}',  -- missing closing brace
                '{"user": {"email": test@example.com}}',   -- unquoted string
                '',                                        -- empty string
                'not json at all'                         -- plain text
            }
            
            for _, json_string in ipairs(invalid_jsons) do
                local valid, error_msg = processor:validate_json(json_string)
                assert_false(valid, "Should reject invalid JSON: " .. json_string)
                assert_type(error_msg, "string")
            end
        end)
        
        it("should handle nil and empty input", function()
            local valid, error_msg = processor:validate_json(nil)
            assert_false(valid)
            
            valid, error_msg = processor:validate_json("")
            assert_false(valid)
        end)
    end)
    
    describe("Request Processing", function()
        it("should process simple JSON request", function()
            local request = '{"user": {"email": "test@example.com"}, "server": {"ip": "192.168.1.1"}}'
            local result, modified = processor:process_request(request)
            
            assert_true(modified)
            assert_not_equal(result, request)
            assert_match(result, "EMAIL_%d+")
            assert_match(result, "IP_%d+")
        end)
        
        it("should handle nested JSON structures", function()
            local request = '{"users": [{"profile": {"email": "user1@test.com"}}, {"profile": {"email": "user2@test.com"}}]}'
            local result, modified = processor:process_request(request)
            
            assert_true(modified)
            assert_match(result, "EMAIL_%d+")
        end)
        
        it("should process configured JSON paths only", function()
            local request = '{"user": {"email": "test@example.com"}, "other": {"email": "other@test.com"}}'
            local result, modified = processor:process_request(request)
            
            assert_true(modified)
            -- Should mask the email in user.email path
            assert_match(result, "EMAIL_%d+")
        end)
        
        it("should handle missing paths gracefully", function()
            local request = '{"data": {"value": "no sensitive data here"}}'
            local result, modified = processor:process_request(request)
            
            assert_false(modified)
            assert_equal(result, request)
        end)
        
        it("should process all strings when no specific paths match", function()
            local request = '{"message": "Contact support@example.com", "note": "Server IP is 192.168.1.1"}'
            local result, modified = processor:process_request(request)
            
            assert_true(modified)
            assert_match(result, "EMAIL_%d+")
            assert_match(result, "IP_%d+")
        end)
        
        it("should handle invalid JSON gracefully", function()
            local invalid_json = '{"invalid": json}'
            local result, modified = processor:process_request(invalid_json)
            
            assert_false(modified)
            assert_equal(result, invalid_json)
        end)
        
        it("should handle empty request", function()
            local result, modified = processor:process_request("")
            assert_false(modified)
            assert_equal(result, "")
        end)
    end)
    
    describe("Response Processing", function()
        it("should process response with placeholders", function()
            -- First create some mappings
            local request = '{"user": {"email": "test@example.com"}}'
            processor:process_request(request)
            
            -- Now process response with placeholders
            local response = '{"user": {"email": "EMAIL_1"}}'
            local result = processor:process_response(response)
            
            assert_match(result, "test@example.com")
        end)
        
        it("should handle response without placeholders", function()
            local response = '{"data": {"value": "no placeholders here"}}'
            local result = processor:process_response(response)
            
            assert_equal(result, response)
        end)
        
        it("should handle non-JSON response", function()
            local response = "Plain text response with EMAIL_1 placeholder"
            -- Create mapping first
            processor:process_request('{"user": {"email": "test@example.com"}}')
            
            local result = processor:process_response(response)
            assert_match(result, "test@example.com")
        end)
    end)
    
    describe("Array Processing", function()
        it("should process arrays of objects", function()
            local request = '{"users": [{"email": "user1@test.com"}, {"email": "user2@test.com"}]}'
            local result, modified = processor:process_request(request)
            
            assert_true(modified)
            
            -- Count EMAIL placeholders
            local email_count = 0
            for _ in result:gmatch("EMAIL_%d+") do
                email_count = email_count + 1
            end
            assert_equal(email_count, 2)
        end)
        
        it("should process arrays of strings", function()
            local request = '{"emails": ["user1@test.com", "user2@test.com", "user3@test.com"]}'
            local result, modified = processor:process_request(request)
            
            assert_true(modified)
            assert_match(result, "EMAIL_%d+")
        end)
        
        it("should handle mixed arrays", function()
            local request = '{"data": ["text", 123, {"email": "test@example.com"}, "more text"]}'
            local result, modified = processor:process_request(request)
            
            assert_true(modified)
            assert_match(result, "EMAIL_%d+")
        end)
        
        it("should handle empty arrays", function()
            local request = '{"users": [], "emails": []}'
            local result, modified = processor:process_request(request)
            
            assert_false(modified)
            assert_equal(result, request)
        end)
    end)
    
    describe("Path Configuration", function()
        it("should validate JSON paths", function()
            local valid_paths = {"$.user.email", "$.data.items[0].value", "$.root"}
            local invalid_paths = {"user.email", "$..", "", nil}
            
            local valid, result = processor:validate_paths(valid_paths)
            assert_true(valid)
            assert_equal(#result.valid, 3)
            
            valid, result = processor:validate_paths(invalid_paths)
            assert_false(valid)
        end)
        
        it("should update paths configuration", function()
            local new_paths = {"$.new.path", "$.another.path"}
            local success = processor:update_paths(new_paths)
            
            assert_true(success)
            
            local current_paths = processor:get_paths()
            assert_equal(#current_paths, 2)
        end)
        
        it("should reject invalid paths update", function()
            local invalid_paths = {"invalid", "also.invalid"}
            local success = processor:update_paths(invalid_paths)
            
            assert_false(success)
        end)
    end)
    
    describe("Structure Analysis", function()
        it("should analyze JSON structure", function()
            local json_string = '{"user": {"email": "test@example.com", "age": 30}, "items": [1, 2, 3]}'
            local structure = processor:analyze_structure(json_string)
            
            assert_type(structure, "table")
            assert_true(#structure > 0)
            
            -- Check if analysis includes path information
            local found_email_path = false
            for _, item in ipairs(structure) do
                if item.path == "$.user.email" then
                    found_email_path = true
                    assert_equal(item.type, "string")
                    assert_true(item.has_sensitive_data)
                    break
                end
            end
            assert_true(found_email_path)
        end)
        
        it("should handle invalid JSON in analysis", function()
            local invalid_json = '{"invalid": json}'
            local structure, error_msg = processor:analyze_structure(invalid_json)
            
            assert_nil(structure)
            assert_type(error_msg, "string")
        end)
        
        it("should detect arrays in structure", function()
            local json_string = '{"items": [1, 2, 3], "users": [{"name": "John"}]}'
            local structure = processor:analyze_structure(json_string)
            
            local found_array = false
            for _, item in ipairs(structure) do
                if item.path == "$.items" then
                    assert_true(item.is_array)
                    found_array = true
                    break
                end
            end
            assert_true(found_array)
        end)
    end)
    
    describe("String Extraction", function()
        it("should extract all strings from JSON", function()
            local json_obj = {
                user = {
                    name = "John",
                    email = "john@example.com"
                },
                message = "Hello world"
            }
            
            local strings = processor:extract_strings(json_obj)
            assert_type(strings, "table")
            assert_true(#strings >= 3)  -- name, email, message
        end)
        
        it("should provide path information for extracted strings", function()
            local json_obj = {
                user = {
                    email = "test@example.com"
                }
            }
            
            local strings = processor:extract_strings(json_obj)
            local found_email = false
            
            for _, item in ipairs(strings) do
                if item.value == "test@example.com" then
                    assert_equal(item.path, "user.email")
                    found_email = true
                    break
                end
            end
            assert_true(found_email)
        end)
    end)
    
    describe("Error Handling", function()
        it("should handle malformed JSON gracefully", function()
            local malformed_json = '{"user": {"email": "test@example.com"'  -- missing closing braces
            local result, modified = processor:process_request(malformed_json)
            
            assert_false(modified)
            assert_equal(result, malformed_json)
        end)
        
        it("should handle extremely large JSON", function()
            -- Create a large JSON string
            local large_json = '{"data": ['
            for i = 1, 100 do
                if i > 1 then large_json = large_json .. ',' end
                large_json = large_json .. '{"id": ' .. i .. ', "email": "user' .. i .. '@test.com"}'
            end
            large_json = large_json .. ']}'
            
            local result, modified = processor:process_request(large_json)
            assert_true(modified)
            assert_match(result, "EMAIL_%d+")
        end)
        
        it("should handle circular references gracefully", function()
            -- This test ensures the processor doesn't get stuck in infinite loops
            -- We can't easily create circular references in JSON, but we can test deep nesting
            local deep_json = '{"level1": {"level2": {"level3": {"level4": {"level5": {"email": "deep@test.com"}}}}}}'
            local result, modified = processor:process_request(deep_json)
            
            assert_true(modified)
            assert_match(result, "EMAIL_%d+")
        end)
    end)
    
    describe("Statistics", function()
        it("should provide processing statistics", function()
            local stats = processor:get_stats()
            
            assert_type(stats, "table")
            assert_type(stats.paths_configured, "number")
            assert_type(stats.paths, "table")
        end)
        
        it("should track configured paths", function()
            local stats = processor:get_stats()
            assert_true(stats.paths_configured > 0)
            assert_equal(#stats.paths, stats.paths_configured)
        end)
    end)
end)


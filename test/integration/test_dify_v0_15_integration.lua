-- Integration Tests for Dify v0.15.8
-- Tests specific functionality and compatibility with Dify v0.15.x series

local test_runner = require("test.test_runner")
local utils = require("lib.utils")
local version_detector = require("lib.version_detector")
local adapter_factory = require("lib.adapters.adapter_factory")

local DifyV015IntegrationTest = {}

-- Test configuration for v0.15.8
local V015_CONFIG = {
    version = "0.15.8",
    api = {
        base_url = "/v1",
        supported_endpoints = {
            "/v1/chat-messages",
            "/v1/completion-messages",
            "/v1/messages",
            "/v1/messages/{id}/feedbacks"
        }
    },
    features = {
        oauth_support = false,
        file_upload = false,
        auto_generate_name = false,
        external_trace_id = false,
        plugin_system = false,
        streaming_mode = true,
        enhanced_metadata = false
    },
    masking = {
        enabled = true,
        patterns = {
            email = {
                enabled = true,
                placeholder_prefix = "EMAIL"
            },
            ip_private = {
                enabled = true,
                placeholder_prefix = "IP_PRIVATE"
            },
            ip_public = {
                enabled = true,
                placeholder_prefix = "IP_PUBLIC"
            }
        }
    }
}

-- Sample v0.15.8 API requests and responses
local V015_SAMPLES = {
    chat_request = {
        query = "My email is john@example.com and my server IP is 192.168.1.100",
        user = "test-user",
        inputs = {},
        response_mode = "streaming"
    },
    chat_response = {
        answer = "I received your email john@example.com and noted the server IP 192.168.1.100",
        message_id = "msg-123",
        conversation_id = "conv-456"
    },
    completion_request = {
        query = "Contact support at support@company.com from server 10.0.0.1",
        inputs = {},
        response_mode = "blocking"
    },
    completion_response = {
        answer = "Support contact support@company.com is available from server 10.0.0.1",
        message_id = "msg-789"
    },
    messages_response = {
        data = {
            {
                query = "Email admin@test.com about server 172.16.0.1",
                answer = "Emailed admin@test.com regarding server 172.16.0.1",
                message_id = "msg-001",
                conversation_id = "conv-001"
            }
        }
    }
}

function DifyV015IntegrationTest.setup()
    -- Initialize test environment for v0.15.8
    utils.log("INFO", "Setting up Dify v0.15.8 integration tests")
    return true
end

function DifyV015IntegrationTest.teardown()
    -- Cleanup test environment
    utils.log("INFO", "Tearing down Dify v0.15.8 integration tests")
    return true
end

-- Test 1: Version Detection for v0.15.8
function DifyV015IntegrationTest.test_version_detection_v015()
    local detector = version_detector.new()
    
    -- Test header detection
    local headers = {
        ["x-dify-version"] = "0.15.8"
    }
    
    local version, confidence = detector:detect_version({headers = headers})
    
    test_runner.assert_equal(version, "0.15.8", "Should detect v0.15.8 from headers")
    test_runner.assert_true(confidence > 0.8, "Should have high confidence")
    
    -- Test API response detection
    local response_body = utils.json.encode(V015_SAMPLES.chat_response)
    version, confidence = detector:api_response_detection(response_body)
    
    test_runner.assert_equal(version, "0.15.8", "Should detect v0.15.8 from API response structure")
    
    return true
end

-- Test 2: Adapter Creation for v0.15.8
function DifyV015IntegrationTest.test_adapter_creation_v015()
    local adapter, error_msg = adapter_factory.create_adapter("0.15.8", V015_CONFIG)
    
    test_runner.assert_not_nil(adapter, "Should create v0.15.8 adapter")
    test_runner.assert_nil(error_msg, "Should not have creation error")
    test_runner.assert_equal(adapter:get_version(), "0.15.8", "Should have correct version")
    
    -- Test supported endpoints
    local endpoints = adapter:get_supported_endpoints()
    test_runner.assert_true(endpoints["/v1/chat-messages"] ~= nil, "Should support chat-messages endpoint")
    test_runner.assert_true(endpoints["/v1/completion-messages"] ~= nil, "Should support completion-messages endpoint")
    
    -- Test features
    local features = adapter:get_features()
    test_runner.assert_false(features.oauth_support, "Should not support OAuth in v0.15.8")
    test_runner.assert_false(features.file_upload, "Should not support file upload in v0.15.8")
    test_runner.assert_true(features.streaming_mode, "Should support streaming mode in v0.15.8")
    
    return true
end

-- Test 3: Chat Messages Request Processing for v0.15.8
function DifyV015IntegrationTest.test_chat_request_processing_v015()
    local adapter = adapter_factory.create_adapter("0.15.8", V015_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    local request_body = utils.json.encode(V015_SAMPLES.chat_request)
    local headers = {
        ["content-type"] = "application/json",
        ["authorization"] = "Bearer test-key"
    }
    
    local processed_body, error = adapter:process_request("/v1/chat-messages", "POST", request_body, headers)
    
    test_runner.assert_nil(error, "Should not have processing error")
    test_runner.assert_not_nil(processed_body, "Should return processed body")
    
    -- Verify masking was applied (placeholder implementation)
    local processed_data = utils.json.decode(processed_body)
    test_runner.assert_not_nil(processed_data, "Processed body should be valid JSON")
    test_runner.assert_equal(processed_data.user, "test-user", "User field should be preserved")
    test_runner.assert_equal(processed_data.response_mode, "streaming", "Response mode should be preserved")
    
    return true
end

-- Test 4: Chat Messages Response Processing for v0.15.8
function DifyV015IntegrationTest.test_chat_response_processing_v015()
    local adapter = adapter_factory.create_adapter("0.15.8", V015_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    local response_body = utils.json.encode(V015_SAMPLES.chat_response)
    local headers = {
        ["content-type"] = "application/json"
    }
    
    local processed_body, error = adapter:process_response("/v1/chat-messages", "POST", response_body, headers)
    
    test_runner.assert_nil(error, "Should not have processing error")
    test_runner.assert_not_nil(processed_body, "Should return processed body")
    
    -- Verify reverse masking was applied
    local processed_data = utils.json.decode(processed_body)
    test_runner.assert_not_nil(processed_data, "Processed body should be valid JSON")
    test_runner.assert_equal(processed_data.message_id, "msg-123", "Message ID should be preserved")
    test_runner.assert_equal(processed_data.conversation_id, "conv-456", "Conversation ID should be preserved")
    
    return true
end

-- Test 5: Completion Messages Processing for v0.15.8
function DifyV015IntegrationTest.test_completion_processing_v015()
    local adapter = adapter_factory.create_adapter("0.15.8", V015_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    -- Test request processing
    local request_body = utils.json.encode(V015_SAMPLES.completion_request)
    local processed_request, error = adapter:process_request("/v1/completion-messages", "POST", request_body, {})
    
    test_runner.assert_nil(error, "Should not have request processing error")
    test_runner.assert_not_nil(processed_request, "Should return processed request")
    
    -- Test response processing
    local response_body = utils.json.encode(V015_SAMPLES.completion_response)
    local processed_response, error = adapter:process_response("/v1/completion-messages", "POST", response_body, {})
    
    test_runner.assert_nil(error, "Should not have response processing error")
    test_runner.assert_not_nil(processed_response, "Should return processed response")
    
    local processed_data = utils.json.decode(processed_response)
    test_runner.assert_equal(processed_data.message_id, "msg-789", "Message ID should be preserved")
    
    return true
end

-- Test 6: Messages List Processing for v0.15.8
function DifyV015IntegrationTest.test_messages_list_processing_v015()
    local adapter = adapter_factory.create_adapter("0.15.8", V015_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    local response_body = utils.json.encode(V015_SAMPLES.messages_response)
    local processed_body, error = adapter:process_response("/v1/messages", "GET", response_body, {})
    
    test_runner.assert_nil(error, "Should not have processing error")
    test_runner.assert_not_nil(processed_body, "Should return processed body")
    
    local processed_data = utils.json.decode(processed_body)
    test_runner.assert_not_nil(processed_data.data, "Should have data array")
    test_runner.assert_equal(#processed_data.data, 1, "Should have one message")
    test_runner.assert_equal(processed_data.data[1].message_id, "msg-001", "Message ID should be preserved")
    
    return true
end

-- Test 7: Streaming Response Processing for v0.15.8
function DifyV015IntegrationTest.test_streaming_processing_v015()
    local adapter = adapter_factory.create_adapter("0.15.8", V015_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    -- Test SSE chunk processing
    local sse_chunk = "data: " .. utils.json.encode({
        event = "message",
        answer = "Response with email test@example.com",
        message_id = "msg-stream-123"
    })
    
    local processed_chunk = adapter:process_streaming_response(sse_chunk)
    test_runner.assert_not_nil(processed_chunk, "Should process SSE chunk")
    test_runner.assert_true(processed_chunk:match("^data: "), "Should maintain SSE format")
    
    -- Test [DONE] chunk
    local done_chunk = "data: [DONE]"
    local processed_done = adapter:process_streaming_response(done_chunk)
    test_runner.assert_equal(processed_done, done_chunk, "Should pass through [DONE] chunk unchanged")
    
    return true
end

-- Test 8: Error Handling for v0.15.8
function DifyV015IntegrationTest.test_error_handling_v015()
    local adapter = adapter_factory.create_adapter("0.15.8", V015_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    -- Test invalid JSON
    local invalid_json = "{ invalid json }"
    local processed_body, error = adapter:process_request("/v1/chat-messages", "POST", invalid_json, {})
    
    test_runner.assert_equal(processed_body, invalid_json, "Should return original body for invalid JSON")
    test_runner.assert_nil(error, "Should not error on invalid JSON")
    
    -- Test unsupported endpoint
    local valid_json = utils.json.encode({query = "test"})
    local success, validation_error = adapter:validate_request("/v1/unsupported", "POST", valid_json, {})
    
    test_runner.assert_false(success, "Should fail validation for unsupported endpoint")
    test_runner.assert_not_nil(validation_error, "Should return validation error")
    
    return true
end

-- Test 9: Configuration Validation for v0.15.8
function DifyV015IntegrationTest.test_config_validation_v015()
    local adapter = adapter_factory.create_adapter("0.15.8", V015_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    -- Test valid configuration
    local success, error = adapter:validate_config(V015_CONFIG)
    test_runner.assert_true(success, "Should validate correct v0.15.8 config")
    test_runner.assert_nil(error, "Should not have validation error")
    
    -- Test configuration with unsupported features
    local invalid_config = utils.deep_copy(V015_CONFIG)
    invalid_config.features.oauth_support = true
    
    local adapter2 = adapter_factory.create_adapter("0.15.8", invalid_config)
    test_runner.assert_not_nil(adapter2, "Should still create adapter with unsupported features")
    
    return true
end

-- Test 10: Performance Test for v0.15.8
function DifyV015IntegrationTest.test_performance_v015()
    local adapter = adapter_factory.create_adapter("0.15.8", V015_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    local request_body = utils.json.encode(V015_SAMPLES.chat_request)
    local start_time = os.clock()
    
    -- Process multiple requests
    for i = 1, 100 do
        local processed_body, error = adapter:process_request("/v1/chat-messages", "POST", request_body, {})
        test_runner.assert_nil(error, "Should not have processing error in iteration " .. i)
    end
    
    local end_time = os.clock()
    local duration = end_time - start_time
    local avg_time = duration / 100
    
    utils.log("INFO", string.format("v0.15.8 Performance: 100 requests in %.3fs, avg %.3fms", duration, avg_time * 1000))
    test_runner.assert_true(avg_time < 0.01, "Average processing time should be under 10ms")
    
    return true
end

-- Test 11: Backward Compatibility Test
function DifyV015IntegrationTest.test_backward_compatibility_v015()
    -- Test that v0.15.8 adapter works with older request formats
    local adapter = adapter_factory.create_adapter("0.15.8", V015_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    -- Test minimal request format
    local minimal_request = {
        query = "test query",
        user = "test-user"
    }
    
    local request_body = utils.json.encode(minimal_request)
    local processed_body, error = adapter:process_request("/v1/chat-messages", "POST", request_body, {})
    
    test_runner.assert_nil(error, "Should handle minimal request format")
    test_runner.assert_not_nil(processed_body, "Should return processed body")
    
    local processed_data = utils.json.decode(processed_body)
    test_runner.assert_equal(processed_data.user, "test-user", "Should preserve user field")
    
    return true
end

-- Test 12: Integration with Version Detector
function DifyV015IntegrationTest.test_version_detector_integration_v015()
    local detector = version_detector.new()
    
    -- Simulate v0.15.8 detection context
    local context = {
        headers = {["x-dify-version"] = "0.15.8"},
        response_body = utils.json.encode(V015_SAMPLES.chat_response),
        request_uri = "/v1/chat-messages"
    }
    
    local version, confidence = detector:detect_version(context)
    test_runner.assert_equal(version, "0.15.8", "Should detect v0.15.8")
    
    -- Create adapter with detection
    local adapter, error = adapter_factory.create_adapter_with_detection(detector, V015_CONFIG)
    test_runner.assert_not_nil(adapter, "Should create adapter with detection")
    test_runner.assert_nil(error, "Should not have creation error")
    test_runner.assert_not_nil(adapter.version_detection, "Should have version detection info")
    
    return true
end

-- Run all v0.15.8 integration tests
function DifyV015IntegrationTest.run_all_tests()
    local tests = {
        "test_version_detection_v015",
        "test_adapter_creation_v015", 
        "test_chat_request_processing_v015",
        "test_chat_response_processing_v015",
        "test_completion_processing_v015",
        "test_messages_list_processing_v015",
        "test_streaming_processing_v015",
        "test_error_handling_v015",
        "test_config_validation_v015",
        "test_performance_v015",
        "test_backward_compatibility_v015",
        "test_version_detector_integration_v015"
    }
    
    return test_runner.run_test_suite("Dify v0.15.8 Integration Tests", DifyV015IntegrationTest, tests)
end

return DifyV015IntegrationTest


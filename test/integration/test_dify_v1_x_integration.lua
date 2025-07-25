-- Integration Tests for Dify v1.7.0
-- Tests enhanced functionality and new features in Dify v1.x series

local test_runner = require("test.test_runner")
local utils = require("lib.utils")
local version_detector = require("lib.version_detector")
local adapter_factory = require("lib.adapters.adapter_factory")

local DifyV1XIntegrationTest = {}

-- Test configuration for v1.7.0
local V1X_CONFIG = {
    version = "1.7.0",
    api = {
        base_url = "/v1",
        supported_endpoints = {
            "/v1/chat-messages",
            "/v1/chat-messages/{message_id}/stop",
            "/v1/chat-messages/{message_id}/suggested",
            "/v1/completion-messages",
            "/v1/files/upload",
            "/v1/messages",
            "/v1/messages/{id}/feedbacks",
            "/v1/audio/speech"
        }
    },
    features = {
        oauth_support = true,
        file_upload = true,
        auto_generate_name = true,
        external_trace_id = true,
        plugin_system = true,
        streaming_mode = true,
        enhanced_metadata = true,
        stop_generation = true,
        suggested_questions = true,
        audio_support = true
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
    },
    oauth = {
        enabled = true,
        client_id = "test_client_id",
        client_secret = "test_client_secret"
    },
    file_upload = {
        enabled = true,
        max_file_size = 100000000
    },
    external_trace = {
        enabled = true,
        generate_if_missing = true
    }
}

-- Sample v1.7.0 API requests and responses with enhanced features
local V1X_SAMPLES = {
    chat_request = {
        query = "My email is john@example.com and my server IP is 192.168.1.100",
        user = "test-user",
        inputs = {},
        response_mode = "streaming",
        auto_generate_name = true,
        files = {
            {
                type = "image",
                content = "Image contains email admin@company.com"
            }
        }
    },
    chat_response = {
        event = "message",
        task_id = "task-123",
        id = "id-456",
        message_id = "msg-123",
        conversation_id = "conv-456",
        mode = "chat",
        answer = "I received your email john@example.com and noted the server IP 192.168.1.100",
        metadata = {
            usage = {
                prompt_tokens = 100,
                completion_tokens = 50,
                total_tokens = 150,
                total_price = "0.001"
            },
            retriever_resources = {
                {
                    position = 1,
                    dataset_id = "dataset-123",
                    content = "Server documentation mentions admin@test.com and IP 10.0.0.1"
                }
            }
        },
        created_at = 1640995200
    },
    completion_request = {
        query = "Contact support at support@company.com from server 10.0.0.1",
        inputs = {},
        response_mode = "blocking",
        user = "test-user"
    },
    completion_response = {
        answer = "Support contact support@company.com is available from server 10.0.0.1",
        message_id = "msg-789",
        task_id = "task-789",
        created_at = 1640995200,
        metadata = {
            usage = {
                prompt_tokens = 80,
                completion_tokens = 40,
                total_tokens = 120
            }
        }
    },
    stop_request = {
        user = "test-user"
    },
    stop_response = {
        result = "success"
    },
    suggested_response = {
        data = {
            "What about security@company.com?",
            "How to configure server 172.16.0.1?"
        }
    },
    file_upload_request = {
        file = {
            name = "document.txt",
            content = "Document contains email info@example.com",
            type = "text/plain"
        },
        user = "test-user"
    },
    file_upload_response = {
        id = "file-123",
        name = "document.txt",
        size = 1024,
        extension = "txt",
        mime_type = "text/plain",
        created_at = 1640995200
    },
    audio_request = {
        text = "Please contact admin@company.com for server 192.168.1.1 issues",
        user = "test-user"
    },
    audio_response = {
        task_id = "audio-task-123"
    }
}

function DifyV1XIntegrationTest.setup()
    -- Initialize test environment for v1.7.0
    utils.log("INFO", "Setting up Dify v1.7.0 integration tests")
    return true
end

function DifyV1XIntegrationTest.teardown()
    -- Cleanup test environment
    utils.log("INFO", "Tearing down Dify v1.7.0 integration tests")
    return true
end

-- Test 1: Version Detection for v1.7.0
function DifyV1XIntegrationTest.test_version_detection_v1x()
    local detector = version_detector.new()
    
    -- Test header detection
    local headers = {
        ["x-dify-version"] = "1.7.0"
    }
    
    local version, confidence = detector:detect_version({headers = headers})
    
    test_runner.assert_equal(version, "1.7.0", "Should detect v1.7.0 from headers")
    test_runner.assert_true(confidence > 0.8, "Should have high confidence")
    
    -- Test enhanced API response detection
    local response_body = utils.json.encode(V1X_SAMPLES.chat_response)
    version, confidence = detector:api_response_detection(response_body)
    
    test_runner.assert_equal(version, "1.7.0", "Should detect v1.7.0 from enhanced API response")
    
    return true
end

-- Test 2: Enhanced Adapter Creation for v1.7.0
function DifyV1XIntegrationTest.test_adapter_creation_v1x()
    local adapter, error_msg = adapter_factory.create_adapter("1.7.0", V1X_CONFIG)
    
    test_runner.assert_not_nil(adapter, "Should create v1.7.0 adapter")
    test_runner.assert_nil(error_msg, "Should not have creation error")
    test_runner.assert_equal(adapter:get_version(), "1.7.0", "Should have correct version")
    
    -- Test enhanced endpoints
    local endpoints = adapter:get_supported_endpoints()
    test_runner.assert_true(endpoints["/v1/chat-messages"] ~= nil, "Should support chat-messages endpoint")
    test_runner.assert_true(endpoints["/v1/chat-messages/{message_id}/stop"] ~= nil, "Should support stop endpoint")
    test_runner.assert_true(endpoints["/v1/files/upload"] ~= nil, "Should support file upload endpoint")
    test_runner.assert_true(endpoints["/v1/audio/speech"] ~= nil, "Should support audio endpoint")
    
    -- Test enhanced features
    local features = adapter:get_features()
    test_runner.assert_true(features.oauth_support, "Should support OAuth in v1.7.0")
    test_runner.assert_true(features.file_upload, "Should support file upload in v1.7.0")
    test_runner.assert_true(features.enhanced_metadata, "Should support enhanced metadata in v1.7.0")
    test_runner.assert_true(features.external_trace_id, "Should support external trace ID in v1.7.0")
    
    return true
end

-- Test 3: Enhanced Chat Messages Request Processing for v1.7.0
function DifyV1XIntegrationTest.test_chat_request_processing_v1x()
    local adapter = adapter_factory.create_adapter("1.7.0", V1X_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    local request_body = utils.json.encode(V1X_SAMPLES.chat_request)
    local headers = {
        ["content-type"] = "application/json",
        ["authorization"] = "Bearer test-key"
    }
    
    local processed_body, error = adapter:process_request("/v1/chat-messages", "POST", request_body, headers)
    
    test_runner.assert_nil(error, "Should not have processing error")
    test_runner.assert_not_nil(processed_body, "Should return processed body")
    
    -- Verify enhanced features were processed
    local processed_data = utils.json.decode(processed_body)
    test_runner.assert_not_nil(processed_data, "Processed body should be valid JSON")
    test_runner.assert_equal(processed_data.user, "test-user", "User field should be preserved")
    test_runner.assert_equal(processed_data.auto_generate_name, true, "Auto generate name should be preserved")
    test_runner.assert_not_nil(processed_data.files, "Files array should be present")
    
    return true
end

-- Test 4: Enhanced Chat Messages Response Processing for v1.7.0
function DifyV1XIntegrationTest.test_chat_response_processing_v1x()
    local adapter = adapter_factory.create_adapter("1.7.0", V1X_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    local response_body = utils.json.encode(V1X_SAMPLES.chat_response)
    local headers = {
        ["content-type"] = "application/json"
    }
    
    local processed_body, error = adapter:process_response("/v1/chat-messages", "POST", response_body, headers)
    
    test_runner.assert_nil(error, "Should not have processing error")
    test_runner.assert_not_nil(processed_body, "Should return processed body")
    
    -- Verify enhanced metadata was processed
    local processed_data = utils.json.decode(processed_body)
    test_runner.assert_not_nil(processed_data, "Processed body should be valid JSON")
    test_runner.assert_equal(processed_data.task_id, "task-123", "Task ID should be preserved")
    test_runner.assert_equal(processed_data.created_at, 1640995200, "Created at should be preserved")
    test_runner.assert_not_nil(processed_data.metadata, "Metadata should be present")
    test_runner.assert_not_nil(processed_data.metadata.usage, "Usage metadata should be present")
    test_runner.assert_not_nil(processed_data.metadata.retriever_resources, "Retriever resources should be present")
    
    return true
end

-- Test 5: Stop Generation Processing for v1.7.0
function DifyV1XIntegrationTest.test_stop_generation_v1x()
    local adapter = adapter_factory.create_adapter("1.7.0", V1X_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    -- Test stop request processing
    local request_body = utils.json.encode(V1X_SAMPLES.stop_request)
    local processed_request, error = adapter:process_request("/v1/chat-messages/msg-123/stop", "POST", request_body, {})
    
    test_runner.assert_nil(error, "Should not have request processing error")
    test_runner.assert_not_nil(processed_request, "Should return processed request")
    
    -- Test stop response processing
    local response_body = utils.json.encode(V1X_SAMPLES.stop_response)
    local processed_response, error = adapter:process_response("/v1/chat-messages/msg-123/stop", "POST", response_body, {})
    
    test_runner.assert_nil(error, "Should not have response processing error")
    test_runner.assert_not_nil(processed_response, "Should return processed response")
    
    local processed_data = utils.json.decode(processed_response)
    test_runner.assert_equal(processed_data.result, "success", "Result should be preserved")
    
    return true
end

-- Test 6: Suggested Questions Processing for v1.7.0
function DifyV1XIntegrationTest.test_suggested_questions_v1x()
    local adapter = adapter_factory.create_adapter("1.7.0", V1X_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    local response_body = utils.json.encode(V1X_SAMPLES.suggested_response)
    local processed_body, error = adapter:process_response("/v1/chat-messages/msg-123/suggested", "GET", response_body, {})
    
    test_runner.assert_nil(error, "Should not have processing error")
    test_runner.assert_not_nil(processed_body, "Should return processed body")
    
    local processed_data = utils.json.decode(processed_body)
    test_runner.assert_not_nil(processed_data.data, "Should have data array")
    test_runner.assert_equal(#processed_data.data, 2, "Should have two suggestions")
    
    return true
end

-- Test 7: File Upload Processing for v1.7.0
function DifyV1XIntegrationTest.test_file_upload_v1x()
    local adapter = adapter_factory.create_adapter("1.7.0", V1X_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    -- Test file upload request processing
    local request_body = utils.json.encode(V1X_SAMPLES.file_upload_request)
    local processed_request, error = adapter:process_request("/v1/files/upload", "POST", request_body, {})
    
    test_runner.assert_nil(error, "Should not have request processing error")
    test_runner.assert_not_nil(processed_request, "Should return processed request")
    
    -- Test file upload response processing
    local response_body = utils.json.encode(V1X_SAMPLES.file_upload_response)
    local processed_response, error = adapter:process_response("/v1/files/upload", "POST", response_body, {})
    
    test_runner.assert_nil(error, "Should not have response processing error")
    test_runner.assert_not_nil(processed_response, "Should return processed response")
    
    local processed_data = utils.json.decode(processed_response)
    test_runner.assert_equal(processed_data.id, "file-123", "File ID should be preserved")
    test_runner.assert_equal(processed_data.mime_type, "text/plain", "MIME type should be preserved")
    
    return true
end

-- Test 8: Audio/TTS Processing for v1.7.0
function DifyV1XIntegrationTest.test_audio_processing_v1x()
    local adapter = adapter_factory.create_adapter("1.7.0", V1X_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    -- Test audio request processing
    local request_body = utils.json.encode(V1X_SAMPLES.audio_request)
    local processed_request, error = adapter:process_request("/v1/audio/speech", "POST", request_body, {})
    
    test_runner.assert_nil(error, "Should not have request processing error")
    test_runner.assert_not_nil(processed_request, "Should return processed request")
    
    -- Test audio response processing
    local response_body = utils.json.encode(V1X_SAMPLES.audio_response)
    local processed_response, error = adapter:process_response("/v1/audio/speech", "POST", response_body, {})
    
    test_runner.assert_nil(error, "Should not have response processing error")
    test_runner.assert_not_nil(processed_response, "Should return processed response")
    
    local processed_data = utils.json.decode(processed_response)
    test_runner.assert_equal(processed_data.task_id, "audio-task-123", "Task ID should be preserved")
    
    return true
end

-- Test 9: Enhanced Streaming Response Processing for v1.7.0
function DifyV1XIntegrationTest.test_enhanced_streaming_v1x()
    local adapter = adapter_factory.create_adapter("1.7.0", V1X_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    -- Test enhanced SSE chunk processing
    local sse_chunk = "data: " .. utils.json.encode({
        event = "message",
        answer = "Response with email test@example.com",
        message_id = "msg-stream-123",
        task_id = "task-stream-123",
        metadata = {
            usage = {
                prompt_tokens = 50,
                completion_tokens = 25
            },
            retriever_resources = {
                {
                    content = "Retrieved content with admin@test.com"
                }
            }
        }
    })
    
    local processed_chunk = adapter:process_streaming_response(sse_chunk)
    test_runner.assert_not_nil(processed_chunk, "Should process enhanced SSE chunk")
    test_runner.assert_true(processed_chunk:match("^data: "), "Should maintain SSE format")
    
    -- Verify enhanced metadata was processed
    local data_part = processed_chunk:match("^data: (.+)")
    local chunk_data = utils.json.decode(data_part)
    test_runner.assert_not_nil(chunk_data.metadata, "Should have metadata in chunk")
    test_runner.assert_not_nil(chunk_data.task_id, "Should have task_id in chunk")
    
    return true
end

-- Test 10: OAuth Configuration Validation for v1.7.0
function DifyV1XIntegrationTest.test_oauth_validation_v1x()
    local adapter = adapter_factory.create_adapter("1.7.0", V1X_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    -- Test valid OAuth configuration
    local success, error = adapter:validate_config(V1X_CONFIG)
    test_runner.assert_true(success, "Should validate correct v1.7.0 config with OAuth")
    test_runner.assert_nil(error, "Should not have validation error")
    
    -- Test invalid OAuth configuration
    local invalid_config = utils.deep_copy(V1X_CONFIG)
    invalid_config.oauth.client_id = nil
    
    local success2, error2 = adapter:validate_config(invalid_config)
    test_runner.assert_false(success2, "Should fail validation for invalid OAuth config")
    test_runner.assert_not_nil(error2, "Should return OAuth validation error")
    
    return true
end

-- Test 11: External Trace ID Processing for v1.7.0
function DifyV1XIntegrationTest.test_external_trace_id_v1x()
    local adapter = adapter_factory.create_adapter("1.7.0", V1X_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    -- Test trace ID generation
    local trace_id = adapter:generate_trace_id()
    test_runner.assert_not_nil(trace_id, "Should generate trace ID")
    test_runner.assert_true(trace_id:match("^trace_"), "Should have trace_ prefix")
    
    -- Test different trace IDs
    local trace_id2 = adapter:generate_trace_id()
    test_runner.assert_not_equal(trace_id, trace_id2, "Should generate unique trace IDs")
    
    return true
end

-- Test 12: Enhanced Performance Test for v1.7.0
function DifyV1XIntegrationTest.test_enhanced_performance_v1x()
    local adapter = adapter_factory.create_adapter("1.7.0", V1X_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    local request_body = utils.json.encode(V1X_SAMPLES.chat_request)
    local response_body = utils.json.encode(V1X_SAMPLES.chat_response)
    local start_time = os.clock()
    
    -- Process multiple enhanced requests
    for i = 1, 100 do
        local processed_request, error1 = adapter:process_request("/v1/chat-messages", "POST", request_body, {})
        test_runner.assert_nil(error1, "Should not have request processing error in iteration " .. i)
        
        local processed_response, error2 = adapter:process_response("/v1/chat-messages", "POST", response_body, {})
        test_runner.assert_nil(error2, "Should not have response processing error in iteration " .. i)
    end
    
    local end_time = os.clock()
    local duration = end_time - start_time
    local avg_time = duration / 200  -- 100 requests + 100 responses
    
    utils.log("INFO", string.format("v1.7.0 Enhanced Performance: 200 operations in %.3fs, avg %.3fms", duration, avg_time * 1000))
    test_runner.assert_true(avg_time < 0.015, "Average processing time should be under 15ms for enhanced features")
    
    return true
end

-- Test 13: Array Field Processing for v1.7.0
function DifyV1XIntegrationTest.test_array_field_processing_v1x()
    local adapter = adapter_factory.create_adapter("1.7.0", V1X_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    -- Test processing array fields in retriever resources
    local test_data = {
        metadata = {
            retriever_resources = {
                {
                    content = "First resource with email admin@test.com"
                },
                {
                    content = "Second resource with IP 192.168.1.1"
                }
            }
        }
    }
    
    local modified = adapter:process_array_field(test_data, "metadata.retriever_resources[*].content")
    test_runner.assert_true(type(modified) == "boolean", "Should return boolean for array processing")
    
    return true
end

-- Test 14: Feature Compatibility Test for v1.7.0
function DifyV1XIntegrationTest.test_feature_compatibility_v1x()
    local adapter = adapter_factory.create_adapter("1.7.0", V1X_CONFIG)
    test_runner.assert_not_nil(adapter, "Adapter should be created")
    
    -- Test all v1.7.0 features are supported
    local features = adapter:get_features()
    local expected_features = {
        "oauth_support",
        "file_upload",
        "auto_generate_name",
        "external_trace_id",
        "plugin_system",
        "streaming_mode",
        "enhanced_metadata",
        "stop_generation",
        "suggested_questions",
        "audio_support"
    }
    
    for _, feature in ipairs(expected_features) do
        test_runner.assert_true(features[feature], "Should support feature: " .. feature)
    end
    
    return true
end

-- Test 15: Integration with Version Detector for v1.7.0
function DifyV1XIntegrationTest.test_version_detector_integration_v1x()
    local detector = version_detector.new()
    
    -- Simulate v1.7.0 detection context with enhanced features
    local context = {
        headers = {["x-dify-version"] = "1.7.0"},
        response_body = utils.json.encode(V1X_SAMPLES.chat_response),
        request_uri = "/v1/chat-messages"
    }
    
    local version, confidence = detector:detect_version(context)
    test_runner.assert_equal(version, "1.7.0", "Should detect v1.7.0")
    
    -- Create adapter with enhanced detection
    local adapter, error = adapter_factory.create_adapter_with_detection(detector, V1X_CONFIG)
    test_runner.assert_not_nil(adapter, "Should create adapter with detection")
    test_runner.assert_nil(error, "Should not have creation error")
    test_runner.assert_not_nil(adapter.version_detection, "Should have version detection info")
    test_runner.assert_true(adapter.version_detection.features.enhanced_metadata, "Should detect enhanced metadata feature")
    
    return true
end

-- Run all v1.7.0 integration tests
function DifyV1XIntegrationTest.run_all_tests()
    local tests = {
        "test_version_detection_v1x",
        "test_adapter_creation_v1x",
        "test_chat_request_processing_v1x",
        "test_chat_response_processing_v1x",
        "test_stop_generation_v1x",
        "test_suggested_questions_v1x",
        "test_file_upload_v1x",
        "test_audio_processing_v1x",
        "test_enhanced_streaming_v1x",
        "test_oauth_validation_v1x",
        "test_external_trace_id_v1x",
        "test_enhanced_performance_v1x",
        "test_array_field_processing_v1x",
        "test_feature_compatibility_v1x",
        "test_version_detector_integration_v1x"
    }
    
    return test_runner.run_test_suite("Dify v1.7.0 Integration Tests", DifyV1XIntegrationTest, tests)
end

return DifyV1XIntegrationTest


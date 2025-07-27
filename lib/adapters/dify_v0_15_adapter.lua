-- Dify v0.15.8 Adapter
-- Handles Dify v0.15.x specific API format and features

local BaseAdapter = require("adapters.base_adapter")
local utils = require("utils")

local DifyV015Adapter = setmetatable({}, {__index = BaseAdapter})
DifyV015Adapter.__index = DifyV015Adapter

function DifyV015Adapter.new(config)
    local self = setmetatable(BaseAdapter.new("0.15.8", config), DifyV015Adapter)
    
    -- Define supported endpoints for v0.15.8
    self.supported_endpoints = {
        ["/v1/chat-messages"] = {
            method = "POST",
            request_fields = {
                "query",      -- required
                "inputs",     -- optional
                "user",       -- required
                "response_mode", -- optional (streaming/blocking)
                "conversation_id" -- optional
            },
            response_fields = {
                "answer",
                "message_id", 
                "conversation_id"
            },
            streaming = true
        },
        ["/v1/completion-messages"] = {
            method = "POST",
            request_fields = {
                "query",      -- required
                "inputs",     -- optional
                "response_mode" -- optional
            },
            response_fields = {
                "answer",
                "message_id"
            },
            streaming = true
        },
        ["/v1/messages"] = {
            method = "GET",
            response_fields = {
                "data[*].query",
                "data[*].answer",
                "data[*].message_id"
            }
        },
        ["/v1/messages/{id}/feedbacks"] = {
            method = "POST",
            request_fields = {
                "rating",
                "content"
            }
        }
    }
    
    -- Authentication methods supported in v0.15.8
    self.authentication_methods = {
        "api_key"  -- Only API key authentication
    }
    
    -- Features available in v0.15.8
    self.features = {
        oauth_support = false,
        file_upload = false,
        auto_generate_name = false,
        external_trace_id = false,
        plugin_system = false,
        streaming_mode = true,
        enhanced_metadata = false,
        basic_masking = true,
        conversation_support = true
    }
    
    utils.log("INFO", "Dify v0.15.8 adapter initialized")
    return self
end

-- Process request for v0.15.8
function DifyV015Adapter:process_request(endpoint, method, body, headers)
    local success, error_msg = self:validate_request(endpoint, method, body, headers)
    if not success then
        return nil, self:handle_error(error_msg, {endpoint = endpoint, method = method})
    end
    
    -- Parse JSON body
    local json_data = self:extract_json_body(body)
    if not json_data then
        return body, nil -- Return original if not JSON
    end
    
    -- Get endpoint configuration
    local endpoint_config = self:get_endpoint_config(endpoint)
    if not endpoint_config then
        return body, nil
    end
    
    -- Apply masking to request fields
    local modified = false
    
    for _, field_path in ipairs(endpoint_config.request_fields or {}) do
        local field_value = self:get_field_value(json_data, field_path)
        if field_value and type(field_value) == "string" then
            local masked_value = self:apply_masking(field_value)
            if masked_value ~= field_value then
                self:set_field_value(json_data, field_path, masked_value)
                modified = true
            end
        end
    end
    
    -- Process headers
    headers = self:process_headers(headers)
    
    if modified then
        local processed_body = self:encode_json_body(json_data)
        utils.log("INFO", "Request processed for v0.15.8: " .. endpoint)
        return processed_body, nil
    end
    
    return body, nil
end

-- Process response for v0.15.8
function DifyV015Adapter:process_response(endpoint, method, body, headers)
    -- Handle streaming responses
    if headers and (headers["content-type"] or ""):match("text/event%-stream") then
        return self:process_streaming_response(body)
    end
    
    -- Parse JSON response
    local json_data = self:extract_json_body(body)
    if not json_data then
        return body, nil
    end
    
    -- Get endpoint configuration
    local endpoint_config = self:get_endpoint_config(endpoint)
    if not endpoint_config then
        return body, nil
    end
    
    -- Apply reverse masking to response fields
    local modified = false
    
    for _, field_path in ipairs(endpoint_config.response_fields or {}) do
        local field_value = self:get_field_value(json_data, field_path)
        if field_value and type(field_value) == "string" then
            local unmasked_value = self:apply_reverse_masking(field_value)
            if unmasked_value ~= field_value then
                self:set_field_value(json_data, field_path, unmasked_value)
                modified = true
            end
        end
    end
    
    if modified then
        local processed_body = self:encode_json_body(json_data)
        utils.log("INFO", "Response processed for v0.15.8: " .. endpoint)
        return processed_body, nil
    end
    
    return body, nil
end

-- Get API paths for v0.15.8
function DifyV015Adapter:get_api_paths()
    local paths = {}
    
    for endpoint, config in pairs(self.supported_endpoints) do
        table.insert(paths, {
            path = endpoint,
            method = config.method,
            request_fields = config.request_fields,
            response_fields = config.response_fields,
            streaming = config.streaming
        })
    end
    
    return paths
end

-- Validate configuration for v0.15.8
function DifyV015Adapter:validate_config(config)
    -- Base validation
    local success, error_msg = self:validate_base_config(config)
    if not success then
        return false, error_msg
    end
    
    -- v0.15.8 specific validation
    if config.features then
        -- Check for unsupported features
        local unsupported_features = {
            "oauth_support",
            "file_upload", 
            "auto_generate_name",
            "external_trace_id",
            "plugin_system"
        }
        
        for _, feature in ipairs(unsupported_features) do
            if config.features[feature] == true then
                utils.log("WARN", "Feature not supported in v0.15.8: " .. feature)
            end
        end
    end
    
    return true, nil
end

-- Helper methods for field access

function DifyV015Adapter:get_field_value(data, field_path)
    if not data or not field_path then
        return nil
    end
    
    -- Handle simple field access
    if not field_path:match("%.") and not field_path:match("%[") then
        return data[field_path]
    end
    
    -- Handle nested field access (simplified)
    local parts = {}
    for part in field_path:gmatch("[^%.]+") do
        table.insert(parts, part)
    end
    
    local current = data
    for _, part in ipairs(parts) do
        if type(current) == "table" then
            current = current[part]
        else
            return nil
        end
    end
    
    return current
end

function DifyV015Adapter:set_field_value(data, field_path, value)
    if not data or not field_path then
        return false
    end
    
    -- Handle simple field access
    if not field_path:match("%.") and not field_path:match("%[") then
        data[field_path] = value
        return true
    end
    
    -- Handle nested field access (simplified)
    local parts = {}
    for part in field_path:gmatch("[^%.]+") do
        table.insert(parts, part)
    end
    
    local current = data
    for i = 1, #parts - 1 do
        local part = parts[i]
        if type(current[part]) ~= "table" then
            current[part] = {}
        end
        current = current[part]
    end
    
    current[parts[#parts]] = value
    return true
end

-- Masking integration (placeholder - will be integrated with existing masking plugin)

function DifyV015Adapter:apply_masking(text)
    -- This will be integrated with the existing masking plugin
    -- For now, return the original text
    return text
end

function DifyV015Adapter:apply_reverse_masking(text)
    -- This will be integrated with the existing masking plugin
    -- For now, return the original text
    return text
end

-- v0.15.8 specific methods

function DifyV015Adapter:handle_conversation(json_data)
    -- Handle conversation_id for v0.15.8
    if json_data.conversation_id then
        utils.log("DEBUG", "Processing conversation: " .. json_data.conversation_id)
    end
    
    return json_data
end

function DifyV015Adapter:handle_streaming_mode(json_data)
    -- Ensure response_mode is valid for v0.15.8
    if json_data.response_mode then
        if json_data.response_mode ~= "streaming" and json_data.response_mode ~= "blocking" then
            json_data.response_mode = "streaming" -- Default to streaming
            utils.log("WARN", "Invalid response_mode, defaulting to streaming")
        end
    end
    
    return json_data
end

-- Get adapter-specific statistics
function DifyV015Adapter:get_adapter_statistics()
    local base_stats = self:get_statistics()
    
    return utils.merge_tables(base_stats, {
        adapter_type = "dify_v0_15",
        supported_features = {
            "basic_masking",
            "conversation_support", 
            "streaming_mode"
        },
        limitations = {
            "no_oauth_support",
            "no_file_upload",
            "no_plugin_system"
        }
    })
end

return DifyV015Adapter


-- Dify v1.x Adapter (v1.7.0+)
-- Handles Dify v1.x specific API format and enhanced features

local BaseAdapter = require("adapters.base_adapter")
local utils = require("utils")

local DifyV1XAdapter = setmetatable({}, {__index = BaseAdapter})
DifyV1XAdapter.__index = DifyV1XAdapter

function DifyV1XAdapter.new(config)
    local self = setmetatable(BaseAdapter.new("1.7.0", config), DifyV1XAdapter)
    
    -- Define supported endpoints for v1.7.0+
    self.supported_endpoints = {
        ["/v1/chat-messages"] = {
            method = "POST",
            request_fields = {
                "query",              -- required
                "inputs",             -- optional
                "user",               -- required
                "response_mode",      -- optional (streaming/blocking)
                "conversation_id",    -- optional
                "files",              -- optional (new in v1.x)
                "auto_generate_name"  -- optional (new in v1.x)
            },
            response_fields = {
                "answer",
                "message_id",
                "conversation_id",
                "task_id",           -- new in v1.x
                "created_at",        -- new in v1.x
                "metadata.usage.prompt_tokens",
                "metadata.usage.completion_tokens",
                "metadata.retriever_resources[*].content"
            },
            streaming = true
        },
        ["/v1/chat-messages/{message_id}/stop"] = {
            method = "POST",
            request_fields = {
                "user"
            },
            response_fields = {
                "result"
            }
        },
        ["/v1/chat-messages/{message_id}/suggested"] = {
            method = "GET",
            response_fields = {
                "data[*]"
            }
        },
        ["/v1/completion-messages"] = {
            method = "POST",
            request_fields = {
                "query",         -- required
                "inputs",        -- optional
                "response_mode", -- optional
                "user"           -- required
            },
            response_fields = {
                "answer",
                "message_id",
                "task_id",      -- new in v1.x
                "created_at",   -- new in v1.x
                "metadata.usage.prompt_tokens",
                "metadata.usage.completion_tokens"
            },
            streaming = true
        },
        ["/v1/files/upload"] = {
            method = "POST",
            request_fields = {
                "file",
                "user"
            },
            response_fields = {
                "id",
                "name",
                "size",
                "extension",
                "mime_type",
                "created_at"
            }
        },
        ["/v1/messages"] = {
            method = "GET",
            response_fields = {
                "data[*].query",
                "data[*].answer", 
                "data[*].message_id",
                "data[*].created_at",
                "data[*].metadata"
            }
        },
        ["/v1/messages/{id}/feedbacks"] = {
            method = "POST",
            request_fields = {
                "rating",
                "content"
            }
        },
        ["/v1/audio/speech"] = {
            method = "POST",
            request_fields = {
                "text",
                "user"
            },
            response_fields = {
                "task_id"
            }
        }
    }
    
    -- Authentication methods supported in v1.x
    self.authentication_methods = {
        "api_key",        -- Bearer token in header
        "oauth2",         -- OAuth 2.0 (new in v1.x)
        "query_param"     -- API key in query parameter (new in v1.x)
    }
    
    -- Features available in v1.x
    self.features = {
        oauth_support = true,
        file_upload = true,
        auto_generate_name = true,
        external_trace_id = true,
        plugin_system = true,
        streaming_mode = true,
        enhanced_metadata = true,
        basic_masking = true,
        conversation_support = true,
        stop_generation = true,
        suggested_questions = true,
        audio_support = true,
        advanced_retrieval = true
    }
    
    utils.log("INFO", "Dify v1.x adapter initialized")
    return self
end

-- Process request for v1.x
function DifyV1XAdapter:process_request(endpoint, method, body, headers)
    local success, error_msg = self:validate_request(endpoint, method, body, headers)
    if not success then
        return nil, self:handle_error(error_msg, {endpoint = endpoint, method = method})
    end
    
    -- Handle file upload endpoints differently
    if endpoint:match("/v1/files/upload") then
        return self:process_file_upload_request(body, headers)
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
    
    -- Apply v1.x specific processing
    json_data = self:handle_enhanced_features(json_data, endpoint)
    
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
    
    -- Process headers with v1.x enhancements
    headers = self:process_v1x_headers(headers)
    
    if modified then
        local processed_body = self:encode_json_body(json_data)
        utils.log("INFO", "Request processed for v1.x: " .. endpoint)
        return processed_body, nil
    end
    
    return body, nil
end

-- Process response for v1.x
function DifyV1XAdapter:process_response(endpoint, method, body, headers)
    -- Handle streaming responses with enhanced metadata
    if headers and (headers["content-type"] or ""):match("text/event%-stream") then
        return self:process_v1x_streaming_response(body)
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
        -- Handle array fields with [*] notation
        if field_path:match("%[%*%]") then
            modified = self:process_array_field(json_data, field_path) or modified
        else
            local field_value = self:get_field_value(json_data, field_path)
            if field_value and type(field_value) == "string" then
                local unmasked_value = self:apply_reverse_masking(field_value)
                if unmasked_value ~= field_value then
                    self:set_field_value(json_data, field_path, unmasked_value)
                    modified = true
                end
            end
        end
    end
    
    if modified then
        local processed_body = self:encode_json_body(json_data)
        utils.log("INFO", "Response processed for v1.x: " .. endpoint)
        return processed_body, nil
    end
    
    return body, nil
end

-- Get API paths for v1.x
function DifyV1XAdapter:get_api_paths()
    local paths = {}
    
    for endpoint, config in pairs(self.supported_endpoints) do
        table.insert(paths, {
            path = endpoint,
            method = config.method,
            request_fields = config.request_fields,
            response_fields = config.response_fields,
            streaming = config.streaming,
            version_specific = true
        })
    end
    
    return paths
end

-- Validate configuration for v1.x
function DifyV1XAdapter:validate_config(config)
    -- Base validation
    local success, error_msg = self:validate_base_config(config)
    if not success then
        return false, error_msg
    end
    
    -- v1.x specific validation
    if config.oauth then
        if not config.oauth.client_id or not config.oauth.client_secret then
            return false, "OAuth configuration requires client_id and client_secret"
        end
    end
    
    if config.file_upload then
        if config.file_upload.max_size and config.file_upload.max_size > 100 * 1024 * 1024 then
            utils.log("WARN", "File upload max_size is very large: " .. config.file_upload.max_size)
        end
    end
    
    return true, nil
end

-- v1.x specific methods

function DifyV1XAdapter:handle_enhanced_features(json_data, endpoint)
    -- Handle auto_generate_name
    if json_data.auto_generate_name == nil and endpoint:match("/chat%-messages") then
        json_data.auto_generate_name = true -- Default to true
    end
    
    -- Handle external trace ID
    if self.config.external_trace_id then
        json_data.external_trace_id = self:generate_trace_id()
    end
    
    -- Handle files array
    if json_data.files and type(json_data.files) == "table" then
        for i, file in ipairs(json_data.files) do
            if file.content then
                -- Mask content in file descriptions
                file.content = self:apply_masking(file.content)
            end
        end
    end
    
    return json_data
end

function DifyV1XAdapter:process_v1x_headers(headers)
    headers = self:process_headers(headers)
    
    -- Add v1.x specific headers
    headers["X-API-Version"] = "1.7.0"
    
    -- Handle external trace ID
    if self.config.external_trace_id then
        headers["X-Trace-ID"] = self:generate_trace_id()
    end
    
    return headers
end

function DifyV1XAdapter:process_v1x_streaming_response(chunk)
    if not chunk then
        return chunk
    end
    
    -- Handle Server-Sent Events format with enhanced metadata
    if chunk:match("^data: ") then
        local data_part = chunk:match("^data: (.+)")
        if data_part and data_part ~= "[DONE]" then
            local json_data = self:extract_json_body(data_part)
            if json_data then
                -- Process enhanced metadata
                if json_data.metadata then
                    json_data.metadata = self:process_metadata(json_data.metadata)
                end
                
                -- Apply reverse masking to answer
                if json_data.answer then
                    json_data.answer = self:apply_reverse_masking(json_data.answer)
                end
                
                return "data: " .. (self:encode_json_body(json_data) or data_part)
            end
        end
    end
    
    return chunk
end

function DifyV1XAdapter:process_metadata(metadata)
    if not metadata then
        return metadata
    end
    
    -- Process retriever resources
    if metadata.retriever_resources then
        for i, resource in ipairs(metadata.retriever_resources) do
            if resource.content then
                resource.content = self:apply_reverse_masking(resource.content)
            end
        end
    end
    
    return metadata
end

function DifyV1XAdapter:process_array_field(data, field_path)
    -- Handle array field processing like "data[*].content"
    local base_path = field_path:gsub("%[%*%]", "")
    local array_field = field_path:match("([^%.]+)%[%*%]")
    local sub_field = field_path:match("%[%*%]%.(.+)")
    
    if not array_field then
        return false
    end
    
    local array_data = self:get_field_value(data, array_field)
    if not array_data or type(array_data) ~= "table" then
        return false
    end
    
    local modified = false
    for i, item in ipairs(array_data) do
        if sub_field then
            local field_value = self:get_field_value(item, sub_field)
            if field_value and type(field_value) == "string" then
                local unmasked_value = self:apply_reverse_masking(field_value)
                if unmasked_value ~= field_value then
                    self:set_field_value(item, sub_field, unmasked_value)
                    modified = true
                end
            end
        else
            if type(item) == "string" then
                local unmasked_value = self:apply_reverse_masking(item)
                if unmasked_value ~= item then
                    array_data[i] = unmasked_value
                    modified = true
                end
            end
        end
    end
    
    return modified
end

function DifyV1XAdapter:process_file_upload_request(body, headers)
    -- Handle multipart/form-data for file uploads
    -- This is a simplified implementation
    utils.log("INFO", "Processing file upload request")
    return body, nil
end

function DifyV1XAdapter:generate_trace_id()
    -- Generate a unique trace ID
    return "trace_" .. utils.generate_uuid()
end

-- Enhanced field access methods

function DifyV1XAdapter:get_field_value(data, field_path)
    if not data or not field_path then
        return nil
    end
    
    -- Handle array notation [*]
    if field_path:match("%[%*%]") then
        return nil -- Arrays should be handled separately
    end
    
    -- Handle simple field access
    if not field_path:match("%.") then
        return data[field_path]
    end
    
    -- Handle nested field access
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

function DifyV1XAdapter:set_field_value(data, field_path, value)
    if not data or not field_path then
        return false
    end
    
    -- Handle simple field access
    if not field_path:match("%.") then
        data[field_path] = value
        return true
    end
    
    -- Handle nested field access
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

function DifyV1XAdapter:apply_masking(text)
    -- This will be integrated with the existing masking plugin
    -- For now, return the original text
    return text
end

function DifyV1XAdapter:apply_reverse_masking(text)
    -- This will be integrated with the existing masking plugin
    -- For now, return the original text
    return text
end

-- Get adapter-specific statistics
function DifyV1XAdapter:get_adapter_statistics()
    local base_stats = self:get_statistics()
    
    return utils.merge_tables(base_stats, {
        adapter_type = "dify_v1_x",
        supported_features = {
            "basic_masking",
            "conversation_support",
            "streaming_mode",
            "oauth_support",
            "file_upload",
            "auto_generate_name",
            "external_trace_id",
            "plugin_system",
            "enhanced_metadata",
            "stop_generation",
            "suggested_questions",
            "audio_support"
        },
        enhancements = {
            "enhanced_metadata_processing",
            "advanced_field_masking",
            "oauth2_authentication",
            "file_upload_support"
        }
    })
end

return DifyV1XAdapter


-- dify_message_api.lua - Specific integration for Dify message API endpoints
-- Author: Manus AI
-- Version: 1.0.0

local utils = require("lib.utils")
local dify_adapter = require("lib.dify_adapter")

local _M = {}

-- Dify Message API Handler
local DifyMessageAPI = {}
DifyMessageAPI.__index = DifyMessageAPI

-- Create new Dify Message API handler
function _M.new(config)
    local self = setmetatable({}, DifyMessageAPI)
    
    self.adapter = dify_adapter.new(config)
    self.config = config or {}
    
    -- Specific configurations for each endpoint
    self.endpoint_configs = {
        chat_messages = {
            path_pattern = "^/v1/chat%-messages$",
            method = "POST",
            request_fields = {
                "query",           -- Main user query
                "inputs.message",  -- Input message
                "inputs.context",  -- Context information
                "conversation_id", -- Conversation identifier
                "user"            -- User information
            },
            response_fields = {
                "answer",                              -- Main response
                "message.answer",                      -- Message answer
                "message.content",                     -- Message content
                "agent_thoughts[*].observation",       -- Agent observations
                "agent_thoughts[*].tool_input",        -- Tool inputs
                "retriever_resources[*].content"       -- Retrieved content
            },
            streaming = true,
            requires_conversation_context = true
        },
        completion_messages = {
            path_pattern = "^/v1/completion%-messages$", 
            method = "POST",
            request_fields = {
                "query",           -- User query
                "inputs.prompt",   -- Prompt template
                "inputs.context",  -- Context data
                "inputs.variables" -- Template variables
            },
            response_fields = {
                "answer",          -- Completion result
                "message.answer",  -- Message answer
                "message.content"  -- Message content
            },
            streaming = true,
            requires_conversation_context = false
        },
        messages_list = {
            path_pattern = "^/v1/messages$",
            method = "GET", 
            response_fields = {
                "data[*].query",                       -- Historical queries
                "data[*].answer",                      -- Historical answers
                "data[*].message.content",             -- Message contents
                "data[*].agent_thoughts[*].observation" -- Agent observations
            },
            streaming = false,
            pagination = true
        },
        message_feedback = {
            path_pattern = "^/v1/messages/[^/]+/feedbacks$",
            method = "POST",
            request_fields = {
                "rating",  -- Feedback rating
                "content"  -- Feedback content
            },
            streaming = false
        }
    }
    
    utils.log("INFO", "Dify Message API handler initialized")
    
    return self
end

-- Identify endpoint type from request
function DifyMessageAPI:identify_endpoint(uri, method)
    for endpoint_name, config in pairs(self.endpoint_configs) do
        if uri:match(config.path_pattern) and method == config.method then
            return endpoint_name, config
        end
    end
    return nil, nil
end

-- Process chat messages request
function DifyMessageAPI:process_chat_messages_request(body, content_type)
    local config = self.endpoint_configs.chat_messages
    
    -- Configure masking paths for chat messages
    local json_paths = {}
    for _, field in ipairs(config.request_fields) do
        table.insert(json_paths, "$." .. field)
    end
    
    -- Update adapter configuration
    self.adapter:update_json_paths(json_paths)
    
    -- Process the request
    local processed_body, modified = self.adapter:process_request("/v1/chat-messages", "POST", body, content_type)
    
    utils.log("INFO", "Chat messages request processed, modified: " .. tostring(modified))
    
    return processed_body, modified
end

-- Process chat messages response
function DifyMessageAPI:process_chat_messages_response(body, content_type, is_streaming)
    local config = self.endpoint_configs.chat_messages
    
    if is_streaming then
        -- Handle streaming response
        return self:process_streaming_response(body, config.response_fields)
    else
        -- Configure masking paths for response
        local json_paths = {}
        for _, field in ipairs(config.response_fields) do
            table.insert(json_paths, "$." .. field)
        end
        
        self.adapter:update_json_paths(json_paths)
        
        -- Process the response
        local processed_body = self.adapter:process_response("/v1/chat-messages", "POST", body, content_type)
        
        utils.log("INFO", "Chat messages response processed")
        
        return processed_body
    end
end

-- Process completion messages request
function DifyMessageAPI:process_completion_messages_request(body, content_type)
    local config = self.endpoint_configs.completion_messages
    
    -- Configure masking paths
    local json_paths = {}
    for _, field in ipairs(config.request_fields) do
        table.insert(json_paths, "$." .. field)
    end
    
    self.adapter:update_json_paths(json_paths)
    
    -- Process the request
    local processed_body, modified = self.adapter:process_request("/v1/completion-messages", "POST", body, content_type)
    
    utils.log("INFO", "Completion messages request processed, modified: " .. tostring(modified))
    
    return processed_body, modified
end

-- Process completion messages response
function DifyMessageAPI:process_completion_messages_response(body, content_type, is_streaming)
    local config = self.endpoint_configs.completion_messages
    
    if is_streaming then
        return self:process_streaming_response(body, config.response_fields)
    else
        local json_paths = {}
        for _, field in ipairs(config.response_fields) do
            table.insert(json_paths, "$." .. field)
        end
        
        self.adapter:update_json_paths(json_paths)
        
        local processed_body = self.adapter:process_response("/v1/completion-messages", "POST", body, content_type)
        
        utils.log("INFO", "Completion messages response processed")
        
        return processed_body
    end
end

-- Process messages list response
function DifyMessageAPI:process_messages_list_response(body, content_type)
    local config = self.endpoint_configs.messages_list
    
    -- Configure masking paths for list response
    local json_paths = {}
    for _, field in ipairs(config.response_fields) do
        table.insert(json_paths, "$." .. field)
    end
    
    self.adapter:update_json_paths(json_paths)
    
    -- Process the response
    local processed_body = self.adapter:process_response("/v1/messages", "GET", body, content_type)
    
    utils.log("INFO", "Messages list response processed")
    
    return processed_body
end

-- Process message feedback request
function DifyMessageAPI:process_message_feedback_request(body, content_type)
    local config = self.endpoint_configs.message_feedback
    
    -- Configure masking paths
    local json_paths = {}
    for _, field in ipairs(config.request_fields) do
        table.insert(json_paths, "$." .. field)
    end
    
    self.adapter:update_json_paths(json_paths)
    
    -- Process the request
    local processed_body, modified = self.adapter:process_request("/v1/messages/feedback", "POST", body, content_type)
    
    utils.log("INFO", "Message feedback request processed, modified: " .. tostring(modified))
    
    return processed_body, modified
end

-- Process streaming response (Server-Sent Events)
function DifyMessageAPI:process_streaming_response(chunk, response_fields)
    -- Check if this is an SSE chunk
    if chunk:match("^data: ") then
        local data_part = chunk:match("^data: (.+)")
        
        if data_part and data_part ~= "[DONE]" then
            -- Try to parse as JSON
            local success, json_data = pcall(utils.json.decode, data_part)
            
            if success and type(json_data) == "table" then
                -- Configure masking paths
                local json_paths = {}
                for _, field in ipairs(response_fields) do
                    table.insert(json_paths, "$." .. field)
                end
                
                self.adapter:update_json_paths(json_paths)
                
                -- Process the JSON data
                local processed_data = self.adapter:process_response("/v1/streaming", "POST", utils.json.encode(json_data), "application/json")
                
                return "data: " .. processed_data .. "\n"
            end
        end
    end
    
    -- Return chunk unchanged if not processable
    return chunk
end

-- Main request processor
function DifyMessageAPI:process_request(uri, method, body, content_type)
    local endpoint_name, endpoint_config = self:identify_endpoint(uri, method)
    
    if not endpoint_name then
        utils.log("DEBUG", "Unknown endpoint: " .. uri .. " " .. method)
        return body, false
    end
    
    utils.log("INFO", "Processing " .. endpoint_name .. " request")
    
    -- Route to specific processor
    if endpoint_name == "chat_messages" then
        return self:process_chat_messages_request(body, content_type)
    elseif endpoint_name == "completion_messages" then
        return self:process_completion_messages_request(body, content_type)
    elseif endpoint_name == "message_feedback" then
        return self:process_message_feedback_request(body, content_type)
    else
        -- Default processing
        return self.adapter:process_request(uri, method, body, content_type)
    end
end

-- Main response processor
function DifyMessageAPI:process_response(uri, method, body, content_type, is_streaming)
    local endpoint_name, endpoint_config = self:identify_endpoint(uri, method)
    
    if not endpoint_name then
        utils.log("DEBUG", "Unknown endpoint for response: " .. uri .. " " .. method)
        return body
    end
    
    utils.log("INFO", "Processing " .. endpoint_name .. " response")
    
    -- Route to specific processor
    if endpoint_name == "chat_messages" then
        return self:process_chat_messages_response(body, content_type, is_streaming)
    elseif endpoint_name == "completion_messages" then
        return self:process_completion_messages_response(body, content_type, is_streaming)
    elseif endpoint_name == "messages_list" then
        return self:process_messages_list_response(body, content_type)
    else
        -- Default processing
        return self.adapter:process_response(uri, method, body, content_type)
    end
end

-- Get API-specific statistics
function DifyMessageAPI:get_api_statistics()
    local base_stats = self.adapter:get_dify_statistics()
    
    -- Add message API specific metrics
    base_stats.message_api = {
        supported_endpoints = {},
        endpoint_usage = {}
    }
    
    for endpoint_name, config in pairs(self.endpoint_configs) do
        table.insert(base_stats.message_api.supported_endpoints, {
            name = endpoint_name,
            path_pattern = config.path_pattern,
            method = config.method,
            streaming = config.streaming or false,
            request_fields = (config.request_fields and #config.request_fields) or 0,
            response_fields = (config.response_fields and #config.response_fields) or 0
        })
    end
    
    return base_stats
end

-- Health check for message API
function DifyMessageAPI:health_check()
    local health = self.adapter:health_check()
    
    -- Add message API specific health info
    health.message_api = {
        endpoints_configured = 0,
        streaming_support = true,
        field_mapping_ready = true
    }
    
    for _ in pairs(self.endpoint_configs) do
        health.message_api.endpoints_configured = health.message_api.endpoints_configured + 1
    end
    
    return health
end

-- Cleanup resources
function DifyMessageAPI:cleanup()
    if self.adapter then
        self.adapter:cleanup()
    end
    
    utils.log("INFO", "Dify Message API handler cleanup completed")
end

-- Export the module
return _M


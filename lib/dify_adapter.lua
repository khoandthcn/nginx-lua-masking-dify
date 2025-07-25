-- dify_adapter.lua - Dify v0.15.8 integration adapter for nginx-lua-masking plugin
-- Author: Manus AI
-- Version: 1.0.0

local utils = require("lib.utils")
local masking_plugin = require("lib.masking_plugin")

local _M = {}

-- Dify API endpoints configuration
local DIFY_ENDPOINTS = {
    ["/v1/chat-messages"] = {
        method = "POST",
        request_paths = {
            "$.query",
            "$.inputs.message", 
            "$.inputs.user_input",
            "$.inputs.context",
            "$.conversation_id",
            "$.user"
        },
        response_paths = {
            "$.answer",
            "$.message.answer",
            "$.message.content", 
            "$.agent_thoughts[*].observation",
            "$.agent_thoughts[*].tool_input"
        },
        streaming = true
    },
    ["/v1/completion-messages"] = {
        method = "POST",
        request_paths = {
            "$.query",
            "$.inputs.prompt",
            "$.inputs.context", 
            "$.inputs.user_input"
        },
        response_paths = {
            "$.answer",
            "$.message.answer",
            "$.message.content"
        },
        streaming = true
    },
    ["/v1/messages"] = {
        method = "GET",
        response_paths = {
            "$.data[*].query",
            "$.data[*].answer",
            "$.data[*].message.content",
            "$.data[*].agent_thoughts[*].observation"
        },
        streaming = false
    }
}

-- Dify Adapter class
local DifyAdapter = {}
DifyAdapter.__index = DifyAdapter

-- Create new Dify adapter instance
function _M.new(config)
    local self = setmetatable({}, DifyAdapter)
    
    self.config = config or {}
    self.masking_plugin = masking_plugin.new(self.config)
    self.endpoints = DIFY_ENDPOINTS
    
    utils.log("INFO", "Dify adapter initialized for v0.15.8")
    
    return self
end

-- Check if request should be processed
function DifyAdapter:should_process_request(uri, method)
    if not uri or not method then
        return false
    end
    
    -- Check exact match first
    local endpoint_config = self.endpoints[uri]
    if endpoint_config and endpoint_config.method == method then
        return true, endpoint_config
    end
    
    -- Check pattern match for parameterized endpoints
    for pattern, config in pairs(self.endpoints) do
        if pattern:match("{.*}") then
            local regex_pattern = pattern:gsub("{[^}]+}", "[^/]+")
            if uri:match("^" .. regex_pattern .. "$") and config.method == method then
                return true, config
            end
        end
    end
    
    return false, nil
end

-- Process Dify request
function DifyAdapter:process_request(uri, method, body, content_type)
    local should_process, endpoint_config = self:should_process_request(uri, method)
    
    if not should_process then
        utils.log("DEBUG", "Skipping request processing for " .. uri)
        return body, false
    end
    
    utils.log("INFO", "Processing Dify request: " .. method .. " " .. uri)
    
    -- Configure JSON paths for this endpoint
    if endpoint_config.request_paths then
        self.masking_plugin:update_json_paths(endpoint_config.request_paths)
    end
    
    -- Process the request
    local processed_body = self.masking_plugin:process_request(body, content_type)
    local modified = (processed_body ~= body)
    
    utils.log("INFO", "Dify request processed, modified: " .. tostring(modified))
    
    return processed_body, modified
end

-- Process Dify response
function DifyAdapter:process_response(uri, method, body, content_type)
    local should_process, endpoint_config = self:should_process_request(uri, method)
    
    if not should_process then
        utils.log("DEBUG", "Skipping response processing for " .. uri)
        return body
    end
    
    utils.log("INFO", "Processing Dify response: " .. method .. " " .. uri)
    
    -- Configure JSON paths for response
    if endpoint_config.response_paths then
        self.masking_plugin:update_json_paths(endpoint_config.response_paths)
    end
    
    -- Process the response (unmask)
    local processed_body = self.masking_plugin:process_response(body, content_type)
    
    utils.log("INFO", "Dify response processed")
    
    return processed_body
end

-- Process streaming response chunk
function DifyAdapter:process_response_chunk(uri, method, chunk, is_last_chunk)
    local should_process, endpoint_config = self:should_process_request(uri, method)
    
    if not should_process or not endpoint_config.streaming then
        return chunk
    end
    
    -- Process streaming chunk
    local processed_chunk = self.masking_plugin:process_response_chunk(chunk, is_last_chunk)
    
    return processed_chunk
end

-- Get Dify-specific statistics
function DifyAdapter:get_dify_statistics()
    local base_stats = self.masking_plugin:get_stats()
    
    -- Add Dify-specific metrics
    base_stats.dify = {
        version = "0.15.8",
        supported_endpoints = {},
        processed_endpoints = {}
    }
    
    -- Count supported endpoints
    for endpoint, config in pairs(self.endpoints) do
        table.insert(base_stats.dify.supported_endpoints, {
            path = endpoint,
            method = config.method,
            streaming = config.streaming or false
        })
    end
    
    return base_stats
end

-- Update Dify endpoint configuration
function DifyAdapter:update_endpoint_config(endpoint, config)
    if not endpoint or not config then
        return false
    end
    
    self.endpoints[endpoint] = config
    utils.log("INFO", "Updated Dify endpoint configuration: " .. endpoint)
    
    return true
end

-- Update JSON paths configuration
function DifyAdapter:update_json_paths(new_paths)
    if not new_paths or type(new_paths) ~= "table" then
        utils.log("ERROR", "Invalid JSON paths provided to Dify adapter")
        return false
    end
    
    -- Update the masking plugin's JSON paths
    local success = self.masking_plugin:update_json_paths(new_paths)
    
    if success then
        utils.log("INFO", "Dify adapter updated JSON paths with " .. #new_paths .. " paths")
    else
        utils.log("ERROR", "Dify adapter failed to update JSON paths")
    end
    
    return success
end

-- Health check for Dify integration
function DifyAdapter:health_check()
    local health = {
        status = "healthy",
        dify_version = "0.15.8",
        adapter_ready = true,
        masking_plugin_ready = false,
        supported_endpoints = 0,
        timestamp = os.time()
    }
    
    -- Check masking plugin health
    local plugin_health = self.masking_plugin:health_check()
    health.masking_plugin_ready = plugin_health.status == "healthy"
    
    -- Count supported endpoints
    for _ in pairs(self.endpoints) do
        health.supported_endpoints = health.supported_endpoints + 1
    end
    
    -- Overall health status
    if not health.masking_plugin_ready then
        health.status = "degraded"
    end
    
    return health
end

-- Cleanup resources
function DifyAdapter:cleanup()
    if self.masking_plugin then
        self.masking_plugin:cleanup()
    end
    
    utils.log("INFO", "Dify adapter cleanup completed")
end

-- Export the module
return _M


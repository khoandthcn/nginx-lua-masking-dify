-- masking_plugin.lua - Main plugin module for nginx-lua-masking
-- Author: Manus AI
-- Version: 1.0.0

local utils = require("utils")
local pattern_matcher = require("pattern_matcher")
local json_processor = require("json_processor")
local stream_handler = require("stream_handler")
local mapping_store = require("mapping_store")

local _M = {}

-- Plugin instance
local MaskingPlugin = {}
MaskingPlugin.__index = MaskingPlugin

-- Default configuration
local DEFAULT_CONFIG = {
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
            static_list = {
                "Google", "Microsoft", "Amazon", "Facebook", "Apple", "Netflix",
                "Tesla", "Twitter", "LinkedIn", "Instagram", "YouTube", "GitHub",
                "Oracle", "IBM", "Intel", "AMD", "NVIDIA", "Samsung", "Sony", "LG"
            },
            placeholder_prefix = "ORG"
        }
    },
    json_paths = {
        "$.user.email",
        "$.user.contact.email",
        "$.server.ip",
        "$.server.host",
        "$.company.name",
        "$.organization",
        "$.client.ip"
    },
    logging = {
        enabled = true,
        level = "INFO"
    },
    performance = {
        max_buffer_size = 1048576,  -- 1MB
        chunk_size = 8192,          -- 8KB
        cleanup_interval = 300      -- 5 minutes
    }
}

-- Create new plugin instance
function _M.new(config)
    local self = setmetatable({}, MaskingPlugin)
    
    -- Merge config with defaults
    self.config = utils.deep_copy(DEFAULT_CONFIG)
    if config then
        self:_merge_config(self.config, config)
    end
    
    -- Validate configuration
    local valid, error_msg = utils.validate_config(self.config)
    if not valid then
        utils.log("ERROR", "Invalid configuration: " .. error_msg)
        return nil, error_msg
    end
    
    -- Set logging level
    if self.config.logging and self.config.logging.level then
        utils.set_log_level(self.config.logging.level)
    end
    
    -- Initialize components
    self.pattern_matcher = pattern_matcher.new(self.config.patterns)
    self.json_processor = json_processor.new(self.pattern_matcher, self.config)
    self.mapping_store = mapping_store.new(self.config.performance)
    
    -- Plugin state
    self.enabled = self.config.enabled
    self.request_count = 0
    self.error_count = 0
    self.start_time = os.time()
    
    utils.log("INFO", "Masking plugin initialized successfully")
    
    return self
end

-- Process incoming request
function MaskingPlugin:process_request(request_body, content_type, request_headers)
    if not self.enabled then
        utils.log("DEBUG", "Plugin disabled, passing request through")
        return request_body, false
    end
    
    self.request_count = self.request_count + 1
    utils.start_timer("plugin_process_request")
    
    -- Check if content type is JSON
    if not self.json_processor:is_json_content(content_type) then
        utils.log("DEBUG", "Non-JSON content type, skipping processing: " .. (content_type or "unknown"))
        utils.end_timer("plugin_process_request")
        return request_body, false
    end
    
    -- Validate request body
    if not request_body or request_body == "" then
        utils.log("DEBUG", "Empty request body, skipping processing")
        utils.end_timer("plugin_process_request")
        return request_body, false
    end
    
    local success, result, modified = self:_safe_process_request(request_body)
    
    local elapsed = utils.end_timer("plugin_process_request")
    
    if success then
        utils.log("INFO", "Request processed successfully in " .. string.format("%.3f", elapsed) .. "s, modified: " .. tostring(modified))
        return result, modified
    else
        self.error_count = self.error_count + 1
        utils.log("ERROR", "Request processing failed: " .. (result or "unknown error"))
        return request_body, false  -- Return original on error
    end
end

-- Process outgoing response
function MaskingPlugin:process_response(response_body, content_type, response_headers)
    if not self.enabled then
        utils.log("DEBUG", "Plugin disabled, passing response through")
        return response_body
    end
    
    utils.start_timer("plugin_process_response")
    
    -- Create stream handler for response processing
    local stream_handler_instance = stream_handler.new(self.pattern_matcher, self.config.performance)
    
    local success, result = self:_safe_process_response(response_body, stream_handler_instance, content_type)
    
    local elapsed = utils.end_timer("plugin_process_response")
    
    if success then
        utils.log("INFO", "Response processed successfully in " .. string.format("%.3f", elapsed) .. "s")
        return result
    else
        self.error_count = self.error_count + 1
        utils.log("ERROR", "Response processing failed: " .. (result or "unknown error"))
        return response_body  -- Return original on error
    end
end

-- Process streaming response (chunk by chunk)
function MaskingPlugin:process_response_chunk(chunk, content_type, is_last_chunk)
    if not self.enabled then
        return chunk
    end
    
    -- Initialize stream handler if not exists
    if not self.stream_handler_instance then
        self.stream_handler_instance = stream_handler.new(self.pattern_matcher, self.config.performance)
    end
    
    local result = ""
    local success, processed_chunk = pcall(self.stream_handler_instance.process_by_content_type, 
                                          self.stream_handler_instance, chunk, content_type)
    
    if success then
        result = processed_chunk
    else
        utils.log("ERROR", "Chunk processing failed: " .. tostring(processed_chunk))
        result = chunk  -- Return original chunk on error
    end
    
    -- Finalize if last chunk
    if is_last_chunk then
        local final_chunk = ""
        success, final_chunk = pcall(self.stream_handler_instance.finalize, self.stream_handler_instance)
        if success and final_chunk ~= "" then
            result = result .. final_chunk
        end
        
        -- Cleanup stream handler
        self.stream_handler_instance = nil
    end
    
    return result
end

-- Safe request processing with error handling
function MaskingPlugin:_safe_process_request(request_body)
    local success, result, modified = pcall(function()
        return self.json_processor:process_request(request_body)
    end)
    
    if success then
        return true, result, modified
    else
        return false, result
    end
end

-- Safe response processing with error handling
function MaskingPlugin:_safe_process_response(response_body, stream_handler_instance, content_type)
    local success, result = pcall(function()
        if content_type and content_type:lower():find("json") then
            return self.json_processor:process_response(response_body)
        else
            -- Use stream handler for non-JSON responses
            local processed = stream_handler_instance:process_by_content_type(response_body, content_type)
            return stream_handler_instance:finalize() .. processed
        end
    end)
    
    if success then
        return true, result
    else
        return false, result
    end
end

-- Merge configuration recursively
function MaskingPlugin:_merge_config(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" and type(target[key]) == "table" then
            self:_merge_config(target[key], value)
        else
            target[key] = value
        end
    end
end

-- Update plugin configuration
function MaskingPlugin:update_config(new_config)
    if not new_config then
        return false, "No configuration provided"
    end
    
    -- Validate new configuration
    local valid, error_msg = utils.validate_config(new_config)
    if not valid then
        return false, error_msg
    end
    
    -- Merge with current config
    self:_merge_config(self.config, new_config)
    
    -- Recreate components with new config
    self.pattern_matcher = pattern_matcher.new(self.config.patterns)
    self.json_processor = json_processor.new(self.pattern_matcher, self.config)
    
    -- Update logging level
    if self.config.logging and self.config.logging.level then
        utils.set_log_level(self.config.logging.level)
    end
    
    utils.log("INFO", "Plugin configuration updated successfully")
    return true, "Configuration updated"
end

-- Enable/disable plugin
function MaskingPlugin:set_enabled(enabled)
    self.enabled = enabled
    utils.log("INFO", "Plugin " .. (enabled and "enabled" or "disabled"))
end

-- Update JSON paths configuration
function MaskingPlugin:update_json_paths(new_paths)
    if not new_paths or type(new_paths) ~= "table" then
        utils.log("ERROR", "Invalid JSON paths provided")
        return false
    end
    
    -- Update the configuration
    self.config.json_paths = new_paths
    
    -- Update the JSON processor if it exists
    if self.json_processor and self.json_processor.update_paths then
        local success = self.json_processor:update_paths(new_paths)
        if success then
            utils.log("INFO", "JSON paths updated with " .. #new_paths .. " paths")
            return true
        else
            utils.log("ERROR", "Failed to update JSON processor paths")
            return false
        end
    end
    
    utils.log("INFO", "JSON paths configuration updated")
    return true
end

-- Get plugin statistics
function MaskingPlugin:get_stats()
    local pattern_stats = self.pattern_matcher:get_stats()
    local json_stats = self.json_processor:get_stats()
    local mapping_stats = self.mapping_store:get_request_stats()
    local global_mapping_stats = mapping_store.get_global_stats()
    
    return {
        plugin = {
            enabled = self.enabled,
            uptime_seconds = os.time() - self.start_time,
            total_requests = self.request_count,
            error_count = self.error_count,
            error_rate = self.request_count > 0 and (self.error_count / self.request_count) or 0
        },
        patterns = pattern_stats,
        json_processing = json_stats,
        current_request_mappings = mapping_stats,
        global_mappings = global_mapping_stats
    }
end

-- Health check
function MaskingPlugin:health_check()
    local health = {
        status = "healthy",
        timestamp = os.time(),
        issues = {}
    }
    
    -- Check if plugin is enabled
    if not self.enabled then
        health.status = "disabled"
        table.insert(health.issues, "Plugin is disabled")
    end
    
    -- Check error rate
    local error_rate = self.request_count > 0 and (self.error_count / self.request_count) or 0
    if error_rate > 0.1 then  -- 10% error rate threshold
        health.status = "warning"
        table.insert(health.issues, "High error rate: " .. string.format("%.2f%%", error_rate * 100))
    end
    
    -- Check mapping store health
    local mapping_health = mapping_store.health_check()
    if mapping_health.status ~= "healthy" then
        health.status = mapping_health.status
        for _, issue in ipairs(mapping_health.issues) do
            table.insert(health.issues, "Mapping store: " .. issue)
        end
    end
    
    -- Add stats
    health.stats = self:get_stats()
    
    return health
end

-- Cleanup resources
function MaskingPlugin:cleanup()
    -- Clear pattern matcher mappings
    if self.pattern_matcher then
        self.pattern_matcher:clear_mappings()
    end
    
    -- Destroy mapping store
    if self.mapping_store then
        self.mapping_store:destroy()
    end
    
    -- Clear stream handler
    self.stream_handler_instance = nil
    
    utils.log("INFO", "Plugin cleanup completed")
end

-- Test plugin functionality
function MaskingPlugin:test(test_data)
    if not test_data then
        return false, "No test data provided"
    end
    
    local results = {
        request_processing = {},
        response_processing = {},
        pattern_matching = {}
    }
    
    -- Test request processing
    if test_data.request then
        local processed, modified = self:process_request(test_data.request, "application/json", {})
        results.request_processing = {
            original = test_data.request,
            processed = processed,
            modified = modified
        }
    end
    
    -- Test response processing
    if test_data.response then
        local processed = self:process_response(test_data.response, "application/json", {})
        results.response_processing = {
            original = test_data.response,
            processed = processed
        }
    end
    
    -- Test pattern matching
    if test_data.patterns then
        for pattern_name, test_string in pairs(test_data.patterns) do
            local success, matches = self.pattern_matcher:test_pattern(pattern_name, test_string)
            results.pattern_matching[pattern_name] = {
                test_string = test_string,
                success = success,
                matches = matches
            }
        end
    end
    
    return true, results
end

-- Export plugin state (for debugging)
function MaskingPlugin:export_state()
    return {
        config = utils.deep_copy(self.config),
        stats = self:get_stats(),
        health = self:health_check(),
        mappings = self.mapping_store:export_mappings()
    }
end

-- Global cleanup function (can be called periodically)
function _M.global_cleanup(max_age_seconds)
    return mapping_store.global_cleanup(max_age_seconds)
end

-- Global statistics
function _M.global_stats()
    return mapping_store.get_global_stats()
end

return _M


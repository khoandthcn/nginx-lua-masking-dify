-- Base Adapter Interface for Dify Multi-Version Support
-- Abstract base class for version-specific adapters

local utils = require("lib.utils")

local BaseAdapter = {}
BaseAdapter.__index = BaseAdapter

function BaseAdapter.new(version, config)
    local self = setmetatable({}, BaseAdapter)
    self.version = version
    self.config = config or {}
    self.supported_endpoints = {}
    self.authentication_methods = {}
    self.features = {}
    
    utils.log("INFO", "Base adapter initialized for version: " .. (version or "unknown"))
    return self
end

-- Abstract methods that must be implemented by subclasses

function BaseAdapter:process_request(endpoint, method, body, headers)
    error("process_request must be implemented by subclass")
end

function BaseAdapter:process_response(endpoint, method, body, headers)
    error("process_response must be implemented by subclass")
end

function BaseAdapter:get_api_paths()
    error("get_api_paths must be implemented by subclass")
end

function BaseAdapter:validate_config(config)
    error("validate_config must be implemented by subclass")
end

-- Common utility methods

function BaseAdapter:get_version()
    return self.version
end

function BaseAdapter:get_supported_endpoints()
    return self.supported_endpoints
end

function BaseAdapter:get_authentication_methods()
    return self.authentication_methods
end

function BaseAdapter:get_features()
    return self.features
end

function BaseAdapter:is_endpoint_supported(endpoint)
    return self.supported_endpoints[endpoint] ~= nil
end

function BaseAdapter:is_feature_supported(feature)
    return self.features[feature] == true
end

function BaseAdapter:get_endpoint_config(endpoint)
    return self.supported_endpoints[endpoint]
end

-- Common request processing utilities

function BaseAdapter:extract_json_body(body)
    if not body then
        return nil
    end
    
    local success, json_data = pcall(utils.json.decode, body)
    if success then
        return json_data
    end
    
    utils.log("WARN", "Failed to parse JSON body")
    return nil
end

function BaseAdapter:encode_json_body(data)
    if not data then
        return nil
    end
    
    local success, json_string = pcall(utils.json.encode, data)
    if success then
        return json_string
    end
    
    utils.log("WARN", "Failed to encode JSON data")
    return nil
end

-- Common header processing

function BaseAdapter:process_headers(headers)
    headers = headers or {}
    
    -- Ensure content-type is set
    if not headers["content-type"] and not headers["Content-Type"] then
        headers["Content-Type"] = "application/json"
    end
    
    return headers
end

function BaseAdapter:add_authentication_header(headers, api_key)
    headers = headers or {}
    
    if api_key then
        headers["Authorization"] = "Bearer " .. api_key
    end
    
    return headers
end

-- Common response processing

function BaseAdapter:process_streaming_response(chunk)
    -- Default implementation for streaming responses
    if not chunk then
        return chunk
    end
    
    -- Handle Server-Sent Events format
    if chunk:match("^data: ") then
        local data_part = chunk:match("^data: (.+)")
        if data_part and data_part ~= "[DONE]" then
            local json_data = self:extract_json_body(data_part)
            if json_data then
                -- Process the JSON data through masking
                return "data: " .. (self:encode_json_body(json_data) or data_part)
            end
        end
    end
    
    return chunk
end

-- Common error handling

function BaseAdapter:handle_error(error_message, context)
    context = context or {}
    
    utils.log("ERROR", string.format("Adapter error [%s]: %s", self.version, error_message))
    
    return {
        error = true,
        message = error_message,
        version = self.version,
        context = context
    }
end

-- Common validation

function BaseAdapter:validate_request(endpoint, method, body, headers)
    -- Basic validation
    if not endpoint then
        return false, "Endpoint is required"
    end
    
    if not method then
        return false, "HTTP method is required"
    end
    
    -- Check if endpoint is supported
    if not self:is_endpoint_supported(endpoint) then
        return false, "Endpoint not supported: " .. endpoint
    end
    
    return true, nil
end

-- Common configuration validation

function BaseAdapter:validate_base_config(config)
    config = config or {}
    
    -- Check required fields
    local required_fields = {"patterns"}
    
    for _, field in ipairs(required_fields) do
        if not config[field] then
            return false, "Missing required config field: " .. field
        end
    end
    
    -- Validate patterns
    if config.patterns then
        for pattern_name, pattern_config in pairs(config.patterns) do
            if not pattern_config.enabled == nil then
                pattern_config.enabled = true
            end
            
            if not pattern_config.placeholder_prefix then
                return false, "Missing placeholder_prefix for pattern: " .. pattern_name
            end
        end
    end
    
    return true, nil
end

-- Common statistics

function BaseAdapter:get_statistics()
    return {
        version = self.version,
        supported_endpoints = utils.table_length(self.supported_endpoints),
        authentication_methods = utils.table_length(self.authentication_methods),
        features = utils.table_length(self.features)
    }
end

-- Common debugging

function BaseAdapter:debug_info()
    return {
        version = self.version,
        supported_endpoints = self.supported_endpoints,
        authentication_methods = self.authentication_methods,
        features = self.features,
        config = self.config
    }
end

return BaseAdapter


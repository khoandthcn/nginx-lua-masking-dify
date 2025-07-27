-- Version Detector Module for Dify Multi-Version Support
-- Detects Dify version and determines compatibility

local utils = require("utils")

local VersionDetector = {}
VersionDetector.__index = VersionDetector

-- Supported Dify versions
local SUPPORTED_VERSIONS = {
    ["0.15.8"] = {
        major = 0,
        minor = 15,
        patch = 8,
        features = {
            oauth_support = false,
            file_upload = false,
            auto_generate_name = false,
            external_trace_id = false,
            plugin_system = false,
            streaming_mode = true,
            enhanced_metadata = false
        }
    },
    ["1.7.0"] = {
        major = 1,
        minor = 7,
        patch = 0,
        features = {
            oauth_support = true,
            file_upload = true,
            auto_generate_name = true,
            external_trace_id = true,
            plugin_system = true,
            streaming_mode = true,
            enhanced_metadata = true
        }
    }
}

-- Version detection methods
local DETECTION_METHODS = {
    "header_detection",
    "api_response_detection", 
    "feature_probing",
    "endpoint_detection"
}

function VersionDetector.new()
    local self = setmetatable({}, VersionDetector)
    self.detected_version = nil
    self.detection_method = nil
    self.confidence = 0
    self.features = {}
    
    utils.log("INFO", "Version detector initialized")
    return self
end

-- Parse version string into components
function VersionDetector:parse_version(version_string)
    if not version_string then
        return nil
    end
    
    -- Remove 'v' prefix if present
    version_string = version_string:gsub("^v", "")
    
    -- Parse major.minor.patch format
    local major, minor, patch = version_string:match("^(%d+)%.(%d+)%.(%d+)")
    
    if major and minor and patch then
        return {
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
            string = version_string
        }
    end
    
    return nil
end

-- Compare two versions
function VersionDetector:compare_versions(version1, version2)
    local v1 = self:parse_version(version1)
    local v2 = self:parse_version(version2)
    
    if not v1 or not v2 then
        return 0
    end
    
    if v1.major ~= v2.major then
        return v1.major > v2.major and 1 or -1
    end
    
    if v1.minor ~= v2.minor then
        return v1.minor > v2.minor and 1 or -1
    end
    
    if v1.patch ~= v2.patch then
        return v1.patch > v2.patch and 1 or -1
    end
    
    return 0
end

-- Detect version from HTTP headers
function VersionDetector:header_detection(headers)
    if not headers then
        return nil, 0
    end
    
    -- Check common version headers
    local version_headers = {
        "x-dify-version",
        "x-api-version", 
        "server",
        "x-powered-by"
    }
    
    for _, header_name in ipairs(version_headers) do
        local header_value = headers[header_name] or headers[header_name:upper()]
        
        if header_value then
            -- Try to extract version from header value
            local version = header_value:match("(%d+%.%d+%.%d+)")
            if version and SUPPORTED_VERSIONS[version] then
                utils.log("INFO", "Version detected from header " .. header_name .. ": " .. version)
                return version, 0.9
            end
        end
    end
    
    return nil, 0
end

-- Detect version from API response structure
function VersionDetector:api_response_detection(response_body)
    if not response_body then
        return nil, 0
    end
    
    local success, response_data = pcall(utils.json.decode, response_body)
    if not success then
        return nil, 0
    end
    
    -- Check for v1.7.0 specific fields
    if response_data.task_id and response_data.created_at and response_data.metadata then
        if response_data.metadata.usage and response_data.metadata.retriever_resources then
            utils.log("INFO", "Version detected from API response: 1.7.0 (enhanced metadata)")
            return "1.7.0", 0.8
        end
    end
    
    -- Check for basic v0.15.8 structure
    if response_data.answer and response_data.message_id and response_data.conversation_id then
        if not response_data.task_id and not response_data.created_at then
            utils.log("INFO", "Version detected from API response: 0.15.8 (basic structure)")
            return "0.15.8", 0.7
        end
    end
    
    return nil, 0
end

-- Detect version through feature probing
function VersionDetector:feature_probing(base_url, api_key)
    if not base_url or not api_key then
        return nil, 0
    end
    
    -- Try to access v1.7.0 specific endpoints
    local v1_endpoints = {
        "/v1/chat-messages/test/stop",
        "/v1/chat-messages/test/suggested"
    }
    
    local has_v1_features = false
    
    for _, endpoint in ipairs(v1_endpoints) do
        local url = base_url .. endpoint
        local headers = {
            ["Authorization"] = "Bearer " .. api_key,
            ["Content-Type"] = "application/json"
        }
        
        -- Make HEAD request to check if endpoint exists
        local success, response = pcall(function()
            -- Simulate HTTP request (in real implementation, use ngx.location.capture)
            return {status = 404} -- Default to not found
        end)
        
        if success and response.status ~= 404 then
            has_v1_features = true
            break
        end
    end
    
    if has_v1_features then
        utils.log("INFO", "Version detected through feature probing: 1.7.0")
        return "1.7.0", 0.6
    else
        utils.log("INFO", "Version detected through feature probing: 0.15.8")
        return "0.15.8", 0.5
    end
end

-- Detect version from endpoint patterns
function VersionDetector:endpoint_detection(request_uri)
    if not request_uri then
        return nil, 0
    end
    
    -- Check for v1.7.0 specific endpoint patterns
    local v1_patterns = {
        "/v1/chat%-messages/[^/]+/stop",
        "/v1/chat%-messages/[^/]+/suggested",
        "/v1/files/upload"
    }
    
    for _, pattern in ipairs(v1_patterns) do
        if request_uri:match(pattern) then
            utils.log("INFO", "Version detected from endpoint pattern: 1.7.0")
            return "1.7.0", 0.7
        end
    end
    
    -- Default to v0.15.8 for basic endpoints
    if request_uri:match("/v1/chat%-messages") or request_uri:match("/v1/completion%-messages") then
        utils.log("INFO", "Version detected from endpoint pattern: 0.15.8 (basic)")
        return "0.15.8", 0.4
    end
    
    return nil, 0
end

-- Main detection function
function VersionDetector:detect_version(context)
    local best_version = nil
    local best_confidence = 0
    local best_method = nil
    
    context = context or {}
    
    -- Try all detection methods
    for _, method_name in ipairs(DETECTION_METHODS) do
        local method = self[method_name]
        if method then
            local version, confidence
            
            -- Call method with appropriate parameters
            if method_name == "header_detection" then
                version, confidence = method(self, context.headers)
            elseif method_name == "api_response_detection" then
                version, confidence = method(self, context.response_body)
            elseif method_name == "endpoint_detection" then
                version, confidence = method(self, context.request_uri)
            elseif method_name == "feature_probing" then
                version, confidence = method(self, context.base_url, context.api_key)
            else
                -- Fallback to original calling convention
                version, confidence = method(self, context.headers, context.response_body, 
                                            context.base_url, context.api_key, context.request_uri)
            end
            
            if version and confidence > best_confidence then
                best_version = version
                best_confidence = confidence
                best_method = method_name
            end
        end
    end
    
    -- Set detected version
    if best_version then
        self.detected_version = best_version
        self.detection_method = best_method
        self.confidence = best_confidence
        self.features = SUPPORTED_VERSIONS[best_version].features
        
        utils.log("INFO", string.format("Dify version detected: %s (method: %s, confidence: %.2f)", 
                 best_version, best_method, best_confidence))
    else
        -- Default to v0.15.8 if no version detected
        self.detected_version = "0.15.8"
        self.detection_method = "default"
        self.confidence = 0.1
        self.features = SUPPORTED_VERSIONS["0.15.8"].features
        
        utils.log("WARN", "No version detected, defaulting to v0.15.8")
    end
    
    return self.detected_version, self.confidence
end

-- Get supported versions
function VersionDetector:get_supported_versions()
    local versions = {}
    for version, _ in pairs(SUPPORTED_VERSIONS) do
        table.insert(versions, version)
    end
    return versions
end

-- Check if version is supported
function VersionDetector:is_version_supported(version)
    return SUPPORTED_VERSIONS[version] ~= nil
end

-- Get version features
function VersionDetector:get_version_features(version)
    version = version or self.detected_version
    if version and SUPPORTED_VERSIONS[version] then
        return SUPPORTED_VERSIONS[version].features
    end
    return {}
end

-- Check if feature is supported
function VersionDetector:is_feature_supported(feature_name, version)
    local features = self:get_version_features(version)
    return features[feature_name] == true
end

-- Get version info
function VersionDetector:get_version_info(version)
    version = version or self.detected_version
    return SUPPORTED_VERSIONS[version]
end

-- Get detection summary
function VersionDetector:get_detection_summary()
    return {
        version = self.detected_version,
        method = self.detection_method,
        confidence = self.confidence,
        features = self.features,
        supported_versions = self:get_supported_versions()
    }
end

return VersionDetector


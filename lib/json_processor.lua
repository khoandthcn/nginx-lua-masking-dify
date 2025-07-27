-- json_processor.lua - JSON processing utilities for nginx-lua-masking plugin
-- Author: Manus AI
-- Version: 1.0.0

local utils = require("utils")

local _M = {}

-- JSON Processor instance
local JsonProcessor = {}
JsonProcessor.__index = JsonProcessor

-- Create new JSON processor instance
function _M.new(pattern_matcher, config)
    local self = setmetatable({}, JsonProcessor)
    
    self.pattern_matcher = pattern_matcher
    self.config = config or {}
    
    -- Default paths to process (if not specified)
    self.default_paths = {
        "$.user.email",
        "$.user.contact.email", 
        "$.server.ip",
        "$.server.host",
        "$.company.name",
        "$.organization",
        "$.client.ip"
    }
    
    -- Paths to process (from config or default)
    self.json_paths = self.config.json_paths or self.default_paths
    
    utils.log("INFO", "JSON processor initialized with " .. #self.json_paths .. " paths to monitor")
    
    return self
end

-- Check if content type is JSON
function JsonProcessor:is_json_content(content_type)
    if not content_type then return false end
    
    local json_types = {
        "application/json",
        "application/json; charset=utf-8",
        "text/json"
    }
    
    content_type = content_type:lower()
    for _, json_type in ipairs(json_types) do
        if content_type:find(json_type, 1, true) then
            return true
        end
    end
    
    return false
end

-- Validate JSON string
function JsonProcessor:validate_json(json_string)
    if not json_string or json_string == "" then
        return false, "Empty JSON string"
    end
    
    -- Try to decode JSON
    local ok, result = pcall(utils.json.decode, json_string)
    if ok then
        return true, result
    else
        return false, "Invalid JSON: " .. tostring(result)
    end
end

-- Process JSON request - mask sensitive data
function JsonProcessor:process_request(json_string)
    utils.start_timer("json_process_request")
    
    -- Validate and parse JSON
    local valid, json_obj = self:validate_json(json_string)
    if not valid then
        utils.log("WARN", "Invalid JSON in request, passing through unchanged: " .. json_obj)
        return json_string, false
    end
    
    local modifications_made = false
    
    -- Process each configured path
    for _, path in ipairs(self.json_paths) do
        local success, modified = self:_process_json_path(json_obj, path)
        if success and modified then
            modifications_made = true
        end
    end
    
    -- Also process all string values recursively if no specific paths matched
    if not modifications_made then
        modifications_made = self:_process_all_strings(json_obj)
    end
    
    -- Convert back to JSON string
    local result_json = utils.json.encode(json_obj)
    
    local elapsed = utils.end_timer("json_process_request")
    utils.log("INFO", "JSON request processing completed in " .. string.format("%.3f", elapsed) .. "s, modified: " .. tostring(modifications_made))
    
    return result_json, modifications_made
end

-- Process JSON response - unmask placeholders
function JsonProcessor:process_response(json_string)
    utils.start_timer("json_process_response")
    
    -- For response, we do simple string replacement of placeholders
    -- This handles both JSON and non-JSON responses
    local result = self.pattern_matcher:unmask_text(json_string)
    
    local elapsed = utils.end_timer("json_process_response")
    utils.log("INFO", "JSON response processing completed in " .. string.format("%.3f", elapsed) .. "s")
    
    return result
end

-- Process specific JSON path
function JsonProcessor:_process_json_path(json_obj, path)
    local value = utils.get_json_value(json_obj, path)
    if not value then
        utils.log("DEBUG", "Path not found or empty: " .. path)
        return true, false
    end
    
    if type(value) == "string" then
        local masked_value = self.pattern_matcher:mask_text(value)
        if masked_value ~= value then
            utils.set_json_value(json_obj, path, masked_value)
            utils.log("DEBUG", "Masked value at path: " .. path)
            return true, true
        end
    elseif type(value) == "table" then
        -- If value is array or object, process recursively
        local modified = self:_process_value_recursive(value)
        if modified then
            utils.set_json_value(json_obj, path, value)
            return true, true
        end
    end
    
    return true, false
end

-- Process all string values in JSON object recursively
function JsonProcessor:_process_all_strings(obj)
    if type(obj) ~= "table" then
        return false
    end
    
    local modifications_made = false
    
    for key, value in pairs(obj) do
        if type(value) == "string" then
            local masked_value = self.pattern_matcher:mask_text(value)
            if masked_value ~= value then
                obj[key] = masked_value
                modifications_made = true
                utils.log("DEBUG", "Masked string value at key: " .. tostring(key))
            end
        elseif type(value) == "table" then
            local modified = self:_process_all_strings(value)
            if modified then
                modifications_made = true
            end
        end
    end
    
    return modifications_made
end

-- Process value recursively (for arrays and nested objects)
function JsonProcessor:_process_value_recursive(value)
    if type(value) ~= "table" then
        return false
    end
    
    local modifications_made = false
    
    -- Check if it's an array
    local is_array = true
    local max_index = 0
    for k, _ in pairs(value) do
        if type(k) ~= "number" or k <= 0 or k ~= math.floor(k) then
            is_array = false
            break
        end
        max_index = math.max(max_index, k)
    end
    
    if is_array then
        -- Process array elements
        for i = 1, max_index do
            if value[i] ~= nil then
                if type(value[i]) == "string" then
                    local masked_value = self.pattern_matcher:mask_text(value[i])
                    if masked_value ~= value[i] then
                        value[i] = masked_value
                        modifications_made = true
                    end
                elseif type(value[i]) == "table" then
                    local modified = self:_process_value_recursive(value[i])
                    if modified then
                        modifications_made = true
                    end
                end
            end
        end
    else
        -- Process object properties
        for k, v in pairs(value) do
            if type(v) == "string" then
                local masked_value = self.pattern_matcher:mask_text(v)
                if masked_value ~= v then
                    value[k] = masked_value
                    modifications_made = true
                end
            elseif type(v) == "table" then
                local modified = self:_process_value_recursive(v)
                if modified then
                    modifications_made = true
                end
            end
        end
    end
    
    return modifications_made
end

-- Extract all string values from JSON (for analysis)
function JsonProcessor:extract_strings(json_obj)
    local strings = {}
    
    local function extract_recursive(obj, path)
        path = path or ""
        
        if type(obj) == "string" then
            table.insert(strings, {path = path, value = obj})
        elseif type(obj) == "table" then
            for key, value in pairs(obj) do
                local new_path = path == "" and tostring(key) or (path .. "." .. tostring(key))
                extract_recursive(value, new_path)
            end
        end
    end
    
    extract_recursive(json_obj)
    return strings
end

-- Validate JSON paths configuration
function JsonProcessor:validate_paths(paths)
    if not paths or type(paths) ~= "table" then
        return false, "Paths must be a table"
    end
    
    local valid_paths = {}
    local invalid_paths = {}
    
    for _, path in ipairs(paths) do
        if utils.validate_json_path(path) then
            table.insert(valid_paths, path)
        else
            table.insert(invalid_paths, path)
        end
    end
    
    if #invalid_paths > 0 then
        utils.log("WARN", "Invalid JSON paths found: " .. table.concat(invalid_paths, ", "))
    end
    
    return #valid_paths > 0, {valid = valid_paths, invalid = invalid_paths}
end

-- Update paths configuration
function JsonProcessor:update_paths(new_paths)
    local valid, result = self:validate_paths(new_paths)
    if valid then
        self.json_paths = result.valid
        utils.log("INFO", "Updated JSON paths configuration with " .. #self.json_paths .. " valid paths")
        return true
    else
        utils.log("ERROR", "Failed to update JSON paths: no valid paths provided")
        return false
    end
end

-- Get current paths configuration
function JsonProcessor:get_paths()
    return utils.deep_copy(self.json_paths)
end

-- Analyze JSON structure (for debugging and configuration)
function JsonProcessor:analyze_structure(json_string)
    local valid, json_obj = self:validate_json(json_string)
    if not valid then
        return nil, json_obj
    end
    
    local structure = {}
    
    local function analyze_recursive(obj, path, depth)
        depth = depth or 0
        if depth > 10 then -- Prevent infinite recursion
            return
        end
        
        if type(obj) == "table" then
            for key, value in pairs(obj) do
                local new_path = path == "" and tostring(key) or (path .. "." .. tostring(key))
                
                local info = {
                    path = "$." .. new_path,
                    type = type(value),
                    depth = depth
                }
                
                if type(value) == "string" then
                    info.length = #value
                    info.has_sensitive_data = self:_contains_sensitive_data(value)
                elseif type(value) == "table" then
                    info.is_array = self:_is_array(value)
                    info.size = utils.table_size(value)
                end
                
                table.insert(structure, info)
                
                if type(value) == "table" then
                    analyze_recursive(value, new_path, depth + 1)
                end
            end
        end
    end
    
    analyze_recursive(json_obj, "", 0)
    return structure
end

-- Check if string contains sensitive data
function JsonProcessor:_contains_sensitive_data(str)
    if not str or str == "" then return false end
    
    -- Use pattern matcher to check for sensitive patterns
    local masked = self.pattern_matcher:mask_text(str)
    return masked ~= str
end

-- Check if table is an array
function JsonProcessor:_is_array(t)
    if type(t) ~= "table" then return false end
    
    local max_index = 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" or k <= 0 or k ~= math.floor(k) then
            return false
        end
        max_index = math.max(max_index, k)
    end
    
    -- Check for gaps in array
    for i = 1, max_index do
        if t[i] == nil then
            return false
        end
    end
    
    return max_index > 0
end

-- Get processing statistics
function JsonProcessor:get_stats()
    return {
        paths_configured = #self.json_paths,
        paths = utils.deep_copy(self.json_paths)
    }
end

return _M


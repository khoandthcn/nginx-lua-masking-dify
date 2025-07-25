-- utils.lua - Common utility functions for nginx-lua-masking plugin
-- Author: Manus AI
-- Version: 1.0.0

local _M = {}

-- JSON library (using cjson if available, fallback to simple implementation)
local json
local ok, cjson = pcall(require, "cjson")
if ok then
    json = cjson
else
    -- Simple JSON fallback implementation
    json = {
        encode = function(obj)
            if type(obj) == "table" then
                local result = "{"
                local first = true
                for k, v in pairs(obj) do
                    if not first then result = result .. "," end
                    result = result .. '"' .. tostring(k) .. '":' .. json.encode(v)
                    first = false
                end
                return result .. "}"
            elseif type(obj) == "string" then
                return '"' .. obj:gsub('"', '\\"') .. '"'
            else
                return tostring(obj)
            end
        end,
        decode = function(str)
            -- Very basic JSON decoder - for production use proper JSON library
            local load_func = load or loadstring
            return load_func("return " .. str:gsub('"([^"]*)":', '["%1"]='):gsub('"([^"]*)"', '"%1"'))()
        end
    }
end

_M.json = json

-- Logging levels
local LOG_LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4
}

_M.LOG_LEVELS = LOG_LEVELS

-- Current log level (default to INFO)
local current_log_level = LOG_LEVELS.INFO

-- Set log level
function _M.set_log_level(level)
    if LOG_LEVELS[level] then
        current_log_level = LOG_LEVELS[level]
    end
end

-- Logging function
function _M.log(level, message, context)
    if LOG_LEVELS[level] and LOG_LEVELS[level] >= current_log_level then
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        local ctx_str = ""
        if context then
            ctx_str = " [" .. tostring(context) .. "]"
        end
        
        -- Use ngx.log if available (Nginx environment)
        if ngx and ngx.log then
            local ngx_level = ngx.ERR
            if level == "DEBUG" then ngx_level = ngx.DEBUG
            elseif level == "INFO" then ngx_level = ngx.INFO
            elseif level == "WARN" then ngx_level = ngx.WARN
            end
            ngx.log(ngx_level, "[MASKING-PLUGIN] " .. level .. ctx_str .. ": " .. message)
        else
            -- Fallback to print for testing
            print(timestamp .. " [MASKING-PLUGIN] " .. level .. ctx_str .. ": " .. message)
        end
    end
end

-- Generate unique ID
function _M.generate_id(prefix)
    prefix = prefix or "ID"
    local timestamp = tostring(os.time())
    local random = tostring(math.random(1000, 9999))
    return prefix .. "_" .. timestamp .. "_" .. random
end

-- Deep copy table
function _M.deep_copy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[_M.deep_copy(orig_key)] = _M.deep_copy(orig_value)
        end
        setmetatable(copy, _M.deep_copy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Check if string is empty or nil
function _M.is_empty(str)
    return str == nil or str == ""
end

-- Trim whitespace from string
function _M.trim(str)
    if not str then return nil end
    return str:match("^%s*(.-)%s*$")
end

-- Split string by delimiter
function _M.split(str, delimiter)
    if not str then return {} end
    delimiter = delimiter or "%s"
    local result = {}
    for match in str:gmatch("([^" .. delimiter .. "]+)") do
        table.insert(result, match)
    end
    return result
end

-- Check if table contains value
function _M.table_contains(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

-- Get table size
function _M.table_size(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Escape special regex characters
function _M.escape_regex(str)
    return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

-- Safe string replacement
function _M.safe_gsub(str, pattern, replacement)
    local ok, result = pcall(string.gsub, str, pattern, replacement)
    if ok then
        return result
    else
        _M.log("WARN", "Regex replacement failed: " .. tostring(result))
        return str
    end
end

-- Validate JSON path (simple validation)
function _M.validate_json_path(path)
    if not path or type(path) ~= "string" then
        return false
    end
    -- Basic validation for JSONPath-like syntax
    return path:match("^%$") ~= nil
end

-- Extract value from JSON object using simple path
function _M.get_json_value(obj, path)
    if not obj or not path then return nil end
    
    -- Remove $ prefix if present
    path = path:gsub("^%$%.", "")
    
    local current = obj
    for part in path:gmatch("[^%.]+") do
        if type(current) == "table" and current[part] ~= nil then
            current = current[part]
        else
            return nil
        end
    end
    return current
end

-- Set value in JSON object using simple path
function _M.set_json_value(obj, path, value)
    if not obj or not path then return false end
    
    -- Remove $ prefix if present
    path = path:gsub("^%$%.", "")
    
    local parts = _M.split(path, ".")
    local current = obj
    
    -- Navigate to parent of target
    for i = 1, #parts - 1 do
        local part = parts[i]
        if type(current[part]) ~= "table" then
            current[part] = {}
        end
        current = current[part]
    end
    
    -- Set the value
    current[parts[#parts]] = value
    return true
end

-- Error handling wrapper
function _M.safe_call(func, ...)
    local ok, result = pcall(func, ...)
    if ok then
        return result
    else
        _M.log("ERROR", "Function call failed: " .. tostring(result))
        return nil
    end
end

-- Memory usage tracking (if available)
function _M.get_memory_usage()
    if collectgarbage then
        return collectgarbage("count")
    end
    return 0
end

-- Performance timer
local timers = {}

function _M.start_timer(name)
    timers[name] = os.clock()
end

function _M.end_timer(name)
    if timers[name] then
        local elapsed = os.clock() - timers[name]
        timers[name] = nil
        return elapsed
    end
    return 0
end

-- Configuration validation
function _M.validate_config(config)
    if type(config) ~= "table" then
        return false, "Configuration must be a table"
    end
    
    -- Check required fields
    if config.patterns == nil then
        return false, "Missing 'patterns' configuration"
    end
    
    if type(config.patterns) ~= "table" then
        return false, "'patterns' must be a table"
    end
    
    -- Validate pattern configurations
    for name, pattern_config in pairs(config.patterns) do
        if type(pattern_config) ~= "table" then
            return false, "Pattern '" .. name .. "' configuration must be a table"
        end
        
        if pattern_config.enabled == nil then
            pattern_config.enabled = true
        end
        
        if pattern_config.enabled and not pattern_config.regex and not pattern_config.static_list then
            return false, "Pattern '" .. name .. "' must have either 'regex' or 'static_list'"
        end
    end
    
    return true, "Configuration is valid"
end

-- Get table length (number of key-value pairs)
function _M.table_length(t)
    if type(t) ~= "table" then
        return 0
    end
    
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- Deep copy table
function _M.deep_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[_M.deep_copy(orig_key)] = _M.deep_copy(orig_value)
        end
        setmetatable(copy, _M.deep_copy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Generate UUID-like string
function _M.generate_uuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

-- Initialize random seed
math.randomseed(os.time())

return _M


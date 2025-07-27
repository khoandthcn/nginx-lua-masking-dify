-- Optimized Utils Module for OpenResty
-- Version: 2.1.0

local _M = {}

-- Use OpenResty's cjson if available, fallback to simple implementation
local json
local ok, cjson = pcall(require, "cjson.safe")
if ok then
    json = cjson
    -- Configure cjson for better performance
    cjson.encode_empty_table_as_object(false)
    cjson.encode_sparse_array(true)
else
    -- Fallback JSON implementation
    json = {
        encode = function(obj)
            if type(obj) == "table" then
                local result = {}
                local is_array = true
                local max_index = 0
                
                -- Check if it's an array
                for k, v in pairs(obj) do
                    if type(k) ~= "number" then
                        is_array = false
                        break
                    end
                    max_index = math.max(max_index, k)
                end
                
                if is_array then
                    table.insert(result, "[")
                    for i = 1, max_index do
                        if i > 1 then table.insert(result, ",") end
                        table.insert(result, json.encode(obj[i]))
                    end
                    table.insert(result, "]")
                else
                    table.insert(result, "{")
                    local first = true
                    for k, v in pairs(obj) do
                        if not first then table.insert(result, ",") end
                        table.insert(result, '"' .. tostring(k) .. '":' .. json.encode(v))
                        first = false
                    end
                    table.insert(result, "}")
                end
                return table.concat(result)
            elseif type(obj) == "string" then
                return '"' .. obj:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
            elseif type(obj) == "number" then
                return tostring(obj)
            elseif type(obj) == "boolean" then
                return obj and "true" or "false"
            elseif obj == nil then
                return "null"
            else
                return '"' .. tostring(obj) .. '"'
            end
        end,
        decode = function(str)
            -- Basic JSON decoder - use proper JSON library in production
            local load_func = load or loadstring
            local safe_str = str:gsub('null', 'nil'):gsub('true', 'true'):gsub('false', 'false')
            safe_str = safe_str:gsub('"([^"]*)":', '["%1"]='):gsub('"([^"]*)"', '"%1"')
            local func = load_func("return " .. safe_str)
            return func and func() or nil
        end
    }
end

_M.json = json

-- Optimized logging for OpenResty
function _M.log(level, message)
    local log_levels = {
        DEBUG = ngx.DEBUG,
        INFO = ngx.INFO,
        WARN = ngx.WARN,
        ERROR = ngx.ERR
    }
    
    local ngx_level = log_levels[level] or ngx.ERR
    local timestamp = ngx.time()
    local formatted_message = "[MASKING-PLUGIN] " .. level .. ": " .. message
    
    if ngx then
        ngx.log(ngx_level, formatted_message)
    else
        print(os.date("%Y-%m-%d %H:%M:%S", timestamp) .. " " .. formatted_message)
    end
end

-- Performance utilities
function _M.get_time_ms()
    if ngx then
        return ngx.now() * 1000
    else
        return os.clock() * 1000
    end
end

function _M.measure_time(func, ...)
    local start_time = _M.get_time_ms()
    local result = func(...)
    local end_time = _M.get_time_ms()
    return result, (end_time - start_time)
end

-- String utilities optimized for pattern matching
function _M.escape_pattern(str)
    return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

function _M.split_string(str, delimiter)
    local result = {}
    local pattern = "([^" .. _M.escape_pattern(delimiter) .. "]+)"
    for match in str:gmatch(pattern) do
        table.insert(result, match)
    end
    return result
end

-- Table utilities
function _M.table_length(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

function _M.table_merge(t1, t2)
    local result = {}
    for k, v in pairs(t1) do
        result[k] = v
    end
    for k, v in pairs(t2) do
        result[k] = v
    end
    return result
end

-- Memory optimization
function _M.clear_table(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

-- Validation utilities
function _M.is_valid_email(email)
    return email:match("^[%w%._%+-]+@[%w%._%+-]+%.%w+$") ~= nil
end

function _M.is_valid_ipv4(ip)
    local parts = _M.split_string(ip, ".")
    if #parts ~= 4 then return false end
    
    for _, part in ipairs(parts) do
        local num = tonumber(part)
        if not num or num < 0 or num > 255 then
            return false
        end
    end
    return true
end

function _M.is_valid_ipv6(ip)
    -- Basic IPv6 validation
    return ip:match("^[0-9a-fA-F:]+$") ~= nil and ip:find("::") ~= nil or ip:match("^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$") ~= nil
end

-- Configuration helpers
function _M.load_config(file_path)
    local file = io.open(file_path, "r")
    if not file then
        return nil, "Cannot open config file: " .. file_path
    end
    
    local content = file:read("*all")
    file:close()
    
    local ok, config = pcall(json.decode, content)
    if not ok then
        return nil, "Invalid JSON in config file: " .. file_path
    end
    
    return config
end

return _M

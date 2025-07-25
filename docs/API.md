# API Documentation - Nginx Lua Masking Plugin

## Table of Contents

1. [Plugin Initialization](#plugin-initialization)
2. [Core Methods](#core-methods)
3. [Configuration Management](#configuration-management)
4. [Statistics and Monitoring](#statistics-and-monitoring)
5. [Utility Functions](#utility-functions)
6. [Error Handling](#error-handling)

## Plugin Initialization

### `masking_plugin.new(config)`

Tạo một instance mới của masking plugin.

**Parameters:**
- `config` (table, optional): Configuration object

**Returns:**
- `plugin` (table): Plugin instance
- `error` (string): Error message nếu initialization failed

**Example:**
```lua
local masking_plugin = require("masking_plugin")

-- With default configuration
local plugin = masking_plugin.new()

-- With custom configuration
local config = {
    enabled = true,
    patterns = {
        email = {
            enabled = true,
            regex = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+%.[a-zA-Z][a-zA-Z]+",
            placeholder_prefix = "EMAIL"
        }
    }
}
local plugin = masking_plugin.new(config)
```

## Core Methods

### `plugin:process_request(body, content_type, headers)`

Xử lý request body để mask sensitive data.

**Parameters:**
- `body` (string): Request body content
- `content_type` (string): Content-Type header value
- `headers` (table): Request headers

**Returns:**
- `masked_body` (string): Body với sensitive data đã được mask
- `modified` (boolean): True nếu có data được mask

**Example:**
```lua
local request_body = '{"user": {"email": "test@example.com"}}'
local masked_body, modified = plugin:process_request(request_body, "application/json", {})

-- Result:
-- masked_body = '{"user": {"email": "EMAIL_1"}}'
-- modified = true
```

### `plugin:process_response(body, content_type, headers)`

Xử lý response body để unmask placeholders.

**Parameters:**
- `body` (string): Response body content
- `content_type` (string): Content-Type header value  
- `headers` (table): Response headers

**Returns:**
- `unmasked_body` (string): Body với placeholders đã được restore

**Example:**
```lua
local response_body = '{"user": {"email": "EMAIL_1"}}'
local unmasked_body = plugin:process_response(response_body, "application/json", {})

-- Result:
-- unmasked_body = '{"user": {"email": "test@example.com"}}'
```

### `plugin:process_response_chunk(chunk, content_type, eof)`

Xử lý response chunk cho streaming data.

**Parameters:**
- `chunk` (string): Data chunk
- `content_type` (string): Content-Type header value
- `eof` (boolean): True nếu đây là chunk cuối cùng

**Returns:**
- `processed_chunk` (string): Chunk đã được process

**Example:**
```lua
-- Process streaming response
local chunk1 = '{"user": {"email": "'
local chunk2 = 'EMAIL_1'
local chunk3 = '"}}'

local result1 = plugin:process_response_chunk(chunk1, "application/json", false)
local result2 = plugin:process_response_chunk(chunk2, "application/json", false)
local result3 = plugin:process_response_chunk(chunk3, "application/json", true)

-- Combined result: '{"user": {"email": "test@example.com"}}'
```

## Configuration Management

### `plugin:update_config(new_config)`

Cập nhật configuration của plugin.

**Parameters:**
- `new_config` (table): New configuration object

**Returns:**
- `success` (boolean): True nếu update thành công
- `message` (string): Success/error message

**Example:**
```lua
local new_config = {
    patterns = {
        email = {
            enabled = false  -- Disable email masking
        }
    }
}

local success, message = plugin:update_config(new_config)
if success then
    print("Configuration updated successfully")
else
    print("Update failed: " .. message)
end
```

### `plugin:get_config()`

Lấy current configuration.

**Returns:**
- `config` (table): Current configuration

**Example:**
```lua
local config = plugin:get_config()
print("Email masking enabled:", config.patterns.email.enabled)
```

### `plugin:set_enabled(enabled)`

Enable/disable plugin.

**Parameters:**
- `enabled` (boolean): True để enable, false để disable

**Example:**
```lua
plugin:set_enabled(false)  -- Disable plugin
plugin:set_enabled(true)   -- Enable plugin
```

## Statistics and Monitoring

### `plugin:get_stats()`

Lấy plugin statistics.

**Returns:**
- `stats` (table): Statistics object

**Example:**
```lua
local stats = plugin:get_stats()

print("Total requests:", stats.plugin.total_requests)
print("Total mappings:", stats.patterns.total_mappings)
print("JSON paths configured:", stats.json_processing.paths_configured)
```

**Stats Structure:**
```lua
{
    plugin = {
        total_requests = 100,
        successful_requests = 95,
        error_count = 5,
        enabled = true
    },
    patterns = {
        total_mappings = 50,
        email_mappings = 20,
        ipv4_mappings = 15,
        org_mappings = 15
    },
    json_processing = {
        paths_configured = 7,
        paths = {"$.user.email", "$.server.ip", ...}
    }
}
```

### `plugin:health_check()`

Thực hiện health check.

**Returns:**
- `health` (table): Health status object

**Example:**
```lua
local health = plugin:health_check()

print("Status:", health.status)  -- "healthy", "warning", "error", "disabled"
print("Timestamp:", health.timestamp)
print("Issues:", #health.issues)
```

**Health Structure:**
```lua
{
    status = "healthy",
    timestamp = 1721826450,
    stats = {...},
    issues = {}
}
```

### `plugin:test(test_data)`

Test plugin functionality.

**Parameters:**
- `test_data` (table, optional): Test data object

**Returns:**
- `success` (boolean): True nếu test passed
- `results` (table): Test results

**Example:**
```lua
local test_data = {
    request = '{"user": {"email": "test@example.com"}}',
    response = '{"user": {"email": "EMAIL_1"}}',
    patterns = {
        email = "Contact us at support@example.com",
        ipv4 = "Server IP is 192.168.1.1"
    }
}

local success, results = plugin:test(test_data)
if success then
    print("All tests passed")
else
    print("Test failed:", results.error)
end
```

## Utility Functions

### `plugin:export_state()`

Export plugin state để backup hoặc debugging.

**Returns:**
- `state` (table): Complete plugin state

**Example:**
```lua
local state = plugin:export_state()
-- state contains config, stats, health, mappings
```

### `plugin:cleanup()`

Cleanup plugin resources.

**Example:**
```lua
plugin:cleanup()  -- Clear all mappings and reset state
```

### Global Functions

### `masking_plugin.global_cleanup(max_age)`

Cleanup global resources.

**Parameters:**
- `max_age` (number): Maximum age in seconds (0 = cleanup all)

**Returns:**
- `result` (table): Cleanup results

**Example:**
```lua
local result = masking_plugin.global_cleanup(3600)  -- Cleanup older than 1 hour
print("Cleaned requests:", result.cleaned_requests)
print("Cleaned mappings:", result.cleaned_mappings)
```

### `masking_plugin.global_stats()`

Lấy global statistics.

**Returns:**
- `stats` (table): Global statistics

**Example:**
```lua
local stats = masking_plugin.global_stats()
print("Total requests processed:", stats.total_requests_processed)
print("Active requests:", stats.active_requests)
print("Total active mappings:", stats.total_active_mappings)
```

## Error Handling

### Error Types

Plugin sử dụng các error types sau:

1. **Configuration Error**: Invalid configuration
2. **Processing Error**: Error during request/response processing
3. **Pattern Error**: Invalid regex pattern
4. **JSON Error**: JSON parsing error
5. **Memory Error**: Out of memory

### Error Response Format

```lua
{
    error = true,
    error_type = "configuration_error",
    message = "Invalid regex pattern for email",
    details = {
        pattern = "email",
        regex = "[invalid"
    }
}
```

### Error Handling Best Practices

```lua
-- Always check for errors
local plugin, error_msg = masking_plugin.new(config)
if not plugin then
    ngx.log(ngx.ERR, "Failed to create plugin: " .. error_msg)
    return
end

-- Graceful degradation
local masked_body, modified = plugin:process_request(body, content_type, {})
if not masked_body then
    -- Use original body if processing failed
    masked_body = body
    modified = false
end

-- Error logging
local success, message = plugin:update_config(new_config)
if not success then
    ngx.log(ngx.WARN, "Config update failed: " .. message)
end
```

## Pattern Matcher API

### `pattern_matcher.new(config)`

Tạo pattern matcher instance.

**Parameters:**
- `config` (table): Pattern configurations

**Returns:**
- `matcher` (table): Pattern matcher instance

### `matcher:mask_text(text)`

Mask sensitive data trong text.

**Parameters:**
- `text` (string): Input text

**Returns:**
- `masked_text` (string): Text với sensitive data đã mask
- `mappings` (table): Mapping information

### `matcher:unmask_text(text)`

Unmask placeholders trong text.

**Parameters:**
- `text` (string): Text with placeholders

**Returns:**
- `unmasked_text` (string): Text với placeholders restored

## JSON Processor API

### `json_processor.new(pattern_matcher, config)`

Tạo JSON processor instance.

**Parameters:**
- `pattern_matcher` (table): Pattern matcher instance
- `config` (table): JSON processing configuration

**Returns:**
- `processor` (table): JSON processor instance

### `processor:process_request(json_string)`

Process JSON request.

**Parameters:**
- `json_string` (string): JSON string

**Returns:**
- `processed_json` (string): Processed JSON
- `modified` (boolean): True nếu có modifications

### `processor:process_response(json_string)`

Process JSON response.

**Parameters:**
- `json_string` (string): JSON string with placeholders

**Returns:**
- `processed_json` (string): JSON với placeholders restored

## Stream Handler API

### `stream_handler.new(pattern_matcher)`

Tạo stream handler instance.

**Parameters:**
- `pattern_matcher` (table): Pattern matcher instance

**Returns:**
- `handler` (table): Stream handler instance

### `handler:process_chunk(chunk, eof)`

Process data chunk.

**Parameters:**
- `chunk` (string): Data chunk
- `eof` (boolean): End of stream flag

**Returns:**
- `processed_chunk` (string): Processed chunk

## Configuration Schema

### Complete Configuration Object

```lua
{
    enabled = true,
    debug = false,
    log_level = "INFO",
    
    patterns = {
        email = {
            enabled = true,
            regex = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+%.[a-zA-Z][a-zA-Z]+",
            placeholder_prefix = "EMAIL",
            case_sensitive = false
        },
        ipv4 = {
            enabled = true,
            regex = "%d+%.%d+%.%d+%.%d+",
            placeholder_prefix = "IP",
            validate = true
        },
        organizations = {
            enabled = true,
            static_list = ["Google", "Microsoft", "Amazon", "Facebook", "Apple"],
            placeholder_prefix = "ORG",
            case_sensitive = false,
            whole_word_only = true
        }
    },
    
    json_paths = [
        "$.user.email",
        "$.user.profile.email", 
        "$.server.ip",
        "$.servers[*].ip",
        "$.company.name",
        "$.contacts[*].email",
        "$.metadata.organization"
    ],
    
    performance = {
        max_mappings = 10000,
        cleanup_interval = 3600,
        memory_limit = "100MB"
    },
    
    security = {
        placeholder_randomization = true,
        mapping_encryption = false
    }
}
```

## Integration Examples

### Nginx Configuration

```nginx
location /api/ {
    access_by_lua_block {
        local masking_plugin = require("masking_plugin")
        local plugin = masking_plugin.new()
        
        ngx.req.read_body()
        local body = ngx.req.get_body_data()
        
        if body then
            local content_type = ngx.req.get_headers()["content-type"]
            local masked_body, modified = plugin:process_request(body, content_type, {})
            
            if modified then
                ngx.req.set_body_data(masked_body)
            end
        end
    }
    
    body_filter_by_lua_block {
        local masking_plugin = require("masking_plugin")
        local plugin = masking_plugin.new()
        
        local chunk = ngx.arg[1]
        local eof = ngx.arg[2]
        
        if chunk then
            local content_type = ngx.header.content_type
            local unmasked_chunk = plugin:process_response_chunk(chunk, content_type, eof)
            ngx.arg[1] = unmasked_chunk
        end
    }
    
    proxy_pass http://backend;
}
```

### OpenResty Integration

```lua
-- In init_by_lua_block
local masking_plugin = require("masking_plugin")
_G.masking_plugin_instance = masking_plugin.new({
    patterns = {
        email = { enabled = true },
        ipv4 = { enabled = true }
    }
})

-- In access_by_lua_block
local plugin = _G.masking_plugin_instance
-- ... process request

-- In body_filter_by_lua_block  
local plugin = _G.masking_plugin_instance
-- ... process response
```


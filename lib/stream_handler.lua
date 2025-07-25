-- stream_handler.lua - Stream data handling for nginx-lua-masking plugin
-- Author: Manus AI
-- Version: 1.0.0

local utils = require("lib.utils")

local _M = {}

-- Stream Handler instance
local StreamHandler = {}
StreamHandler.__index = StreamHandler

-- Create new stream handler instance
function _M.new(pattern_matcher, config)
    local self = setmetatable({}, StreamHandler)
    
    self.pattern_matcher = pattern_matcher
    self.config = config or {}
    
    -- Configuration parameters
    self.chunk_size = self.config.chunk_size or 8192  -- 8KB chunks
    self.max_buffer_size = self.config.max_buffer_size or 1048576  -- 1MB max buffer
    self.buffer_timeout = self.config.buffer_timeout or 5  -- 5 seconds timeout
    
    -- Internal state
    self.buffer = ""
    self.total_processed = 0
    self.chunks_processed = 0
    self.start_time = os.time()
    
    utils.log("INFO", "Stream handler initialized with chunk_size=" .. self.chunk_size .. ", max_buffer=" .. self.max_buffer_size)
    
    return self
end

-- Process stream data chunk by chunk
function StreamHandler:process_chunk(chunk)
    if not chunk or chunk == "" then
        return ""
    end
    
    utils.start_timer("stream_process_chunk")
    
    -- Add chunk to buffer
    self.buffer = self.buffer .. chunk
    self.chunks_processed = self.chunks_processed + 1
    
    local result = ""
    local processed_length = 0
    
    -- Check buffer size limit
    if #self.buffer > self.max_buffer_size then
        utils.log("WARN", "Buffer size exceeded limit, processing partial buffer")
        result = self:_process_buffer_content(self.buffer)
        self.buffer = ""
        processed_length = #result
    else
        -- Look for complete data boundaries (JSON objects, lines, etc.)
        local boundary_pos = self:_find_processing_boundary(self.buffer)
        
        if boundary_pos > 0 then
            -- Process complete data up to boundary
            local complete_data = self.buffer:sub(1, boundary_pos)
            result = self:_process_buffer_content(complete_data)
            
            -- Keep remaining data in buffer
            self.buffer = self.buffer:sub(boundary_pos + 1)
            processed_length = #complete_data
        else
            -- No complete boundary found, check timeout
            if self:_should_flush_buffer() then
                result = self:_process_buffer_content(self.buffer)
                self.buffer = ""
                processed_length = #result
            end
        end
    end
    
    self.total_processed = self.total_processed + processed_length
    
    local elapsed = utils.end_timer("stream_process_chunk")
    utils.log("DEBUG", "Processed chunk: " .. #chunk .. " bytes, buffer: " .. #self.buffer .. " bytes, time: " .. string.format("%.3f", elapsed) .. "s")
    
    return result
end

-- Finalize stream processing (process remaining buffer)
function StreamHandler:finalize()
    utils.start_timer("stream_finalize")
    
    local result = ""
    if #self.buffer > 0 then
        result = self:_process_buffer_content(self.buffer)
        self.buffer = ""
    end
    
    local elapsed = utils.end_timer("stream_finalize")
    local total_time = os.time() - self.start_time
    
    utils.log("INFO", "Stream processing finalized: " .. self.total_processed .. " bytes processed in " .. 
              self.chunks_processed .. " chunks over " .. total_time .. " seconds")
    
    return result
end

-- Find appropriate boundary for processing
function StreamHandler:_find_processing_boundary(data)
    if not data or data == "" then
        return 0
    end
    
    -- Look for JSON object boundaries
    local json_boundary = self:_find_json_boundary(data)
    if json_boundary > 0 then
        return json_boundary
    end
    
    -- Look for line boundaries
    local line_boundary = data:find("\n[^\n]*$")
    if line_boundary then
        return line_boundary
    end
    
    -- Look for sentence boundaries
    local sentence_boundary = data:find("%.[%s]*[A-Z]")
    if sentence_boundary then
        return sentence_boundary
    end
    
    -- If no good boundary found, return 0 (wait for more data)
    return 0
end

-- Find JSON object boundary
function StreamHandler:_find_json_boundary(data)
    local brace_count = 0
    local in_string = false
    local escape_next = false
    
    for i = 1, #data do
        local char = data:sub(i, i)
        
        if escape_next then
            escape_next = false
        elseif char == "\\" then
            escape_next = true
        elseif char == '"' and not escape_next then
            in_string = not in_string
        elseif not in_string then
            if char == "{" then
                brace_count = brace_count + 1
            elseif char == "}" then
                brace_count = brace_count - 1
                if brace_count == 0 then
                    return i  -- Found complete JSON object
                end
            end
        end
    end
    
    return 0  -- No complete JSON object found
end

-- Check if buffer should be flushed due to timeout or other conditions
function StreamHandler:_should_flush_buffer()
    -- Check timeout
    local current_time = os.time()
    if current_time - self.start_time > self.buffer_timeout then
        return true
    end
    
    -- Check if buffer contains only whitespace or simple text
    if self.buffer:match("^%s*$") then
        return true
    end
    
    -- Check if buffer looks like plain text (no JSON structure)
    if not self.buffer:find("[{}%[%]]") and #self.buffer > 1000 then
        return true
    end
    
    return false
end

-- Process buffer content (apply unmasking)
function StreamHandler:_process_buffer_content(content)
    if not content or content == "" then
        return ""
    end
    
    utils.start_timer("stream_unmask_content")
    
    -- Apply reverse mapping (unmask placeholders)
    local result = self.pattern_matcher:unmask_text(content)
    
    local elapsed = utils.end_timer("stream_unmask_content")
    utils.log("DEBUG", "Unmasked " .. #content .. " bytes in " .. string.format("%.3f", elapsed) .. "s")
    
    return result
end

-- Process streaming JSON response
function StreamHandler:process_json_stream(chunk)
    if not chunk or chunk == "" then
        return ""
    end
    
    -- For JSON streams, we need to be more careful about boundaries
    self.buffer = self.buffer .. chunk
    
    local result = ""
    local processed = false
    
    -- Try to find complete JSON objects
    local start_pos = 1
    while start_pos <= #self.buffer do
        local obj_start = self.buffer:find("{", start_pos)
        if not obj_start then
            break
        end
        
        local obj_end = self:_find_json_boundary(self.buffer:sub(obj_start))
        if obj_end > 0 then
            -- Found complete JSON object
            local json_obj = self.buffer:sub(obj_start, obj_start + obj_end - 1)
            local processed_obj = self:_process_buffer_content(json_obj)
            result = result .. processed_obj
            
            start_pos = obj_start + obj_end
            processed = true
        else
            break
        end
    end
    
    if processed then
        -- Remove processed data from buffer
        self.buffer = self.buffer:sub(start_pos)
    end
    
    return result
end

-- Handle different content types
function StreamHandler:process_by_content_type(chunk, content_type)
    if not chunk or chunk == "" then
        return ""
    end
    
    content_type = content_type or ""
    content_type = content_type:lower()
    
    if content_type:find("application/json") then
        return self:process_json_stream(chunk)
    elseif content_type:find("text/") then
        return self:process_chunk(chunk)
    elseif content_type:find("application/xml") then
        return self:process_chunk(chunk)  -- Treat XML like text
    else
        -- For binary or unknown content types, pass through without processing
        utils.log("DEBUG", "Skipping processing for content type: " .. content_type)
        return chunk
    end
end

-- Reset handler state (for reuse)
function StreamHandler:reset()
    self.buffer = ""
    self.total_processed = 0
    self.chunks_processed = 0
    self.start_time = os.time()
    
    utils.log("DEBUG", "Stream handler reset")
end

-- Get current buffer status
function StreamHandler:get_buffer_status()
    return {
        buffer_size = #self.buffer,
        total_processed = self.total_processed,
        chunks_processed = self.chunks_processed,
        processing_time = os.time() - self.start_time,
        buffer_preview = self.buffer:sub(1, 100) .. (#self.buffer > 100 and "..." or "")
    }
end

-- Adaptive chunk size based on content
function StreamHandler:_adapt_chunk_size(content_type)
    content_type = content_type or ""
    content_type = content_type:lower()
    
    if content_type:find("application/json") then
        -- Smaller chunks for JSON to respect object boundaries
        return math.min(self.chunk_size, 4096)
    elseif content_type:find("text/plain") then
        -- Larger chunks for plain text
        return math.max(self.chunk_size, 16384)
    else
        return self.chunk_size
    end
end

-- Performance monitoring
function StreamHandler:get_performance_stats()
    local current_time = os.time()
    local total_time = current_time - self.start_time
    
    return {
        total_bytes_processed = self.total_processed,
        total_chunks = self.chunks_processed,
        processing_time_seconds = total_time,
        average_chunk_size = self.chunks_processed > 0 and (self.total_processed / self.chunks_processed) or 0,
        throughput_bytes_per_second = total_time > 0 and (self.total_processed / total_time) or 0,
        current_buffer_size = #self.buffer
    }
end

-- Memory usage optimization
function StreamHandler:optimize_memory()
    -- Force garbage collection if buffer is large
    if #self.buffer > self.max_buffer_size / 2 then
        collectgarbage("collect")
        utils.log("DEBUG", "Forced garbage collection due to large buffer")
    end
end

-- Error recovery
function StreamHandler:handle_processing_error(error_msg, chunk)
    utils.log("ERROR", "Stream processing error: " .. error_msg)
    
    -- Try to recover by clearing buffer and returning original chunk
    self.buffer = ""
    
    -- Log error context
    utils.log("DEBUG", "Error context - chunk size: " .. #chunk .. ", buffer was: " .. #self.buffer .. " bytes")
    
    -- Return original chunk unchanged
    return chunk
end

return _M


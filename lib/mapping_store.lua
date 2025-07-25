-- mapping_store.lua - Mapping storage and retrieval for nginx-lua-masking plugin
-- Author: Manus AI
-- Version: 1.0.0

local utils = require("lib.utils")

local _M = {}

-- Global storage for mappings (shared across requests)
local global_mappings = {}
local request_mappings = {}  -- Per-request mappings
local mapping_stats = {
    total_requests = 0,
    active_mappings = 0,
    memory_usage = 0
}

-- Mapping Store instance
local MappingStore = {}
MappingStore.__index = MappingStore

-- Create new mapping store instance
function _M.new(config)
    local self = setmetatable({}, MappingStore)
    
    self.config = config or {}
    
    -- Configuration parameters
    self.max_mappings_per_request = self.config.max_mappings_per_request or 1000
    self.cleanup_interval = self.config.cleanup_interval or 300  -- 5 minutes
    self.max_memory_usage = self.config.max_memory_usage or 10485760  -- 10MB
    
    -- Request-specific storage
    self.request_id = utils.generate_id("REQ")
    self.mappings = {}
    self.created_at = os.time()
    self.last_accessed = os.time()
    
    -- Register this request in global storage
    request_mappings[self.request_id] = self
    mapping_stats.total_requests = mapping_stats.total_requests + 1
    
    utils.log("INFO", "Mapping store created for request: " .. self.request_id)
    
    return self
end

-- Store mapping for current request
function MappingStore:store_mapping(original_value, placeholder, pattern_type)
    if not original_value or not placeholder then
        utils.log("WARN", "Invalid mapping parameters")
        return false
    end
    
    -- Check mapping limit
    if utils.table_size(self.mappings) >= self.max_mappings_per_request then
        utils.log("WARN", "Maximum mappings per request exceeded: " .. self.max_mappings_per_request)
        return false
    end
    
    -- Store mapping
    self.mappings[placeholder] = {
        original_value = original_value,
        pattern_type = pattern_type or "unknown",
        created_at = os.time(),
        access_count = 0
    }
    
    self.last_accessed = os.time()
    mapping_stats.active_mappings = mapping_stats.active_mappings + 1
    
    utils.log("DEBUG", "Stored mapping: " .. placeholder .. " -> " .. original_value .. " (type: " .. (pattern_type or "unknown") .. ")")
    
    return true
end

-- Retrieve original value by placeholder
function MappingStore:get_original_value(placeholder)
    if not placeholder then
        return nil
    end
    
    local mapping = self.mappings[placeholder]
    if mapping then
        mapping.access_count = mapping.access_count + 1
        self.last_accessed = os.time()
        
        utils.log("DEBUG", "Retrieved mapping: " .. placeholder .. " -> " .. mapping.original_value)
        return mapping.original_value
    end
    
    return nil
end

-- Get all mappings for current request
function MappingStore:get_all_mappings()
    local result = {}
    for placeholder, mapping in pairs(self.mappings) do
        result[placeholder] = mapping.original_value
    end
    return result
end

-- Clear all mappings for current request
function MappingStore:clear_mappings()
    local count = utils.table_size(self.mappings)
    self.mappings = {}
    mapping_stats.active_mappings = mapping_stats.active_mappings - count
    
    utils.log("INFO", "Cleared " .. count .. " mappings for request: " .. self.request_id)
end

-- Export mappings to external format
function MappingStore:export_mappings()
    local exported = {
        request_id = self.request_id,
        created_at = self.created_at,
        last_accessed = self.last_accessed,
        mappings = {}
    }
    
    for placeholder, mapping in pairs(self.mappings) do
        exported.mappings[placeholder] = {
            original_value = mapping.original_value,
            pattern_type = mapping.pattern_type,
            created_at = mapping.created_at,
            access_count = mapping.access_count
        }
    end
    
    return exported
end

-- Import mappings from external format
function MappingStore:import_mappings(imported_data)
    if not imported_data or not imported_data.mappings then
        return false
    end
    
    local imported_count = 0
    for placeholder, mapping in pairs(imported_data.mappings) do
        if self:store_mapping(mapping.original_value, placeholder, mapping.pattern_type) then
            -- Restore additional metadata
            if self.mappings[placeholder] then
                self.mappings[placeholder].created_at = mapping.created_at or os.time()
                self.mappings[placeholder].access_count = mapping.access_count or 0
            end
            imported_count = imported_count + 1
        end
    end
    
    utils.log("INFO", "Imported " .. imported_count .. " mappings for request: " .. self.request_id)
    return imported_count > 0
end

-- Get mapping statistics for current request
function MappingStore:get_request_stats()
    local stats = {
        request_id = self.request_id,
        total_mappings = utils.table_size(self.mappings),
        created_at = self.created_at,
        last_accessed = self.last_accessed,
        age_seconds = os.time() - self.created_at,
        pattern_breakdown = {}
    }
    
    -- Count mappings by pattern type
    for _, mapping in pairs(self.mappings) do
        local pattern_type = mapping.pattern_type
        stats.pattern_breakdown[pattern_type] = (stats.pattern_breakdown[pattern_type] or 0) + 1
    end
    
    return stats
end

-- Cleanup expired mappings
function MappingStore:cleanup_expired(max_age_seconds)
    max_age_seconds = max_age_seconds or 3600  -- 1 hour default
    
    local current_time = os.time()
    local cleaned_count = 0
    
    for placeholder, mapping in pairs(self.mappings) do
        if current_time - mapping.created_at > max_age_seconds then
            self.mappings[placeholder] = nil
            cleaned_count = cleaned_count + 1
        end
    end
    
    if cleaned_count > 0 then
        mapping_stats.active_mappings = mapping_stats.active_mappings - cleaned_count
        utils.log("INFO", "Cleaned up " .. cleaned_count .. " expired mappings for request: " .. self.request_id)
    end
    
    return cleaned_count
end

-- Destroy mapping store (cleanup on request completion)
function MappingStore:destroy()
    local count = utils.table_size(self.mappings)
    
    -- Clear mappings
    self:clear_mappings()
    
    -- Remove from global registry
    request_mappings[self.request_id] = nil
    
    utils.log("INFO", "Destroyed mapping store for request: " .. self.request_id .. " (had " .. count .. " mappings)")
end

-- Global functions for managing all mapping stores

-- Get global mapping statistics
function _M.get_global_stats()
    local active_requests = utils.table_size(request_mappings)
    local total_mappings = 0
    
    for _, store in pairs(request_mappings) do
        total_mappings = total_mappings + utils.table_size(store.mappings)
    end
    
    mapping_stats.active_mappings = total_mappings
    mapping_stats.memory_usage = utils.get_memory_usage()
    
    return {
        total_requests_processed = mapping_stats.total_requests,
        active_requests = active_requests,
        total_active_mappings = total_mappings,
        memory_usage_kb = mapping_stats.memory_usage
    }
end

-- Global cleanup of expired requests
function _M.global_cleanup(max_age_seconds)
    max_age_seconds = max_age_seconds or 3600  -- 1 hour default
    
    local current_time = os.time()
    local cleaned_requests = 0
    local cleaned_mappings = 0
    
    for request_id, store in pairs(request_mappings) do
        if current_time - store.last_accessed > max_age_seconds then
            cleaned_mappings = cleaned_mappings + utils.table_size(store.mappings)
            store:destroy()
            cleaned_requests = cleaned_requests + 1
        else
            -- Cleanup expired mappings within active requests
            cleaned_mappings = cleaned_mappings + store:cleanup_expired(max_age_seconds)
        end
    end
    
    if cleaned_requests > 0 or cleaned_mappings > 0 then
        utils.log("INFO", "Global cleanup: removed " .. cleaned_requests .. " requests and " .. cleaned_mappings .. " mappings")
    end
    
    -- Force garbage collection if memory usage is high
    if mapping_stats.memory_usage > 50000 then  -- 50MB
        collectgarbage("collect")
        utils.log("INFO", "Forced garbage collection due to high memory usage")
    end
    
    return {
        cleaned_requests = cleaned_requests,
        cleaned_mappings = cleaned_mappings
    }
end

-- Find mapping store by request ID
function _M.get_store_by_request_id(request_id)
    return request_mappings[request_id]
end

-- Get all active request IDs
function _M.get_active_request_ids()
    local ids = {}
    for request_id, _ in pairs(request_mappings) do
        table.insert(ids, request_id)
    end
    return ids
end

-- Emergency cleanup (clear all mappings)
function _M.emergency_cleanup()
    local total_requests = utils.table_size(request_mappings)
    local total_mappings = 0
    
    for _, store in pairs(request_mappings) do
        total_mappings = total_mappings + utils.table_size(store.mappings)
        store:clear_mappings()
    end
    
    request_mappings = {}
    mapping_stats.active_mappings = 0
    
    collectgarbage("collect")
    
    utils.log("WARN", "Emergency cleanup: cleared " .. total_requests .. " requests and " .. total_mappings .. " mappings")
    
    return {
        cleared_requests = total_requests,
        cleared_mappings = total_mappings
    }
end

-- Health check for mapping storage
function _M.health_check()
    local stats = _M.get_global_stats()
    local health = {
        status = "healthy",
        issues = {}
    }
    
    -- Check memory usage
    if stats.memory_usage_kb > 100000 then  -- 100MB
        health.status = "warning"
        table.insert(health.issues, "High memory usage: " .. stats.memory_usage_kb .. "KB")
    end
    
    -- Check number of active requests
    if stats.active_requests > 1000 then
        health.status = "warning"
        table.insert(health.issues, "High number of active requests: " .. stats.active_requests)
    end
    
    -- Check average mappings per request
    local avg_mappings = stats.active_requests > 0 and (stats.total_active_mappings / stats.active_requests) or 0
    if avg_mappings > 500 then
        health.status = "warning"
        table.insert(health.issues, "High average mappings per request: " .. string.format("%.1f", avg_mappings))
    end
    
    health.stats = stats
    return health
end

return _M


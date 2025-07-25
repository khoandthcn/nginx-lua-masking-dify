-- Adapter Factory for Dify Multi-Version Support
-- Creates appropriate adapter based on detected Dify version

local utils = require("lib.utils")

local AdapterFactory = {}

-- Available adapters
local ADAPTERS = {
    ["0.15.8"] = "lib.adapters.dify_v0_15_adapter",
    ["1.7.0"] = "lib.adapters.dify_v1_x_adapter"
}

-- Version compatibility mapping
local VERSION_COMPATIBILITY = {
    -- v0.15.x versions
    ["0.15.0"] = "0.15.8",
    ["0.15.1"] = "0.15.8", 
    ["0.15.2"] = "0.15.8",
    ["0.15.3"] = "0.15.8",
    ["0.15.4"] = "0.15.8",
    ["0.15.5"] = "0.15.8",
    ["0.15.6"] = "0.15.8",
    ["0.15.7"] = "0.15.8",
    ["0.15.8"] = "0.15.8",
    
    -- v1.x versions
    ["1.0.0"] = "1.7.0",
    ["1.1.0"] = "1.7.0",
    ["1.2.0"] = "1.7.0",
    ["1.3.0"] = "1.7.0",
    ["1.4.0"] = "1.7.0",
    ["1.4.1"] = "1.7.0",
    ["1.5.0"] = "1.7.0",
    ["1.6.0"] = "1.7.0",
    ["1.7.0"] = "1.7.0"
}

-- Create adapter for specific version
function AdapterFactory.create_adapter(version, config)
    if not version then
        utils.log("ERROR", "Version is required to create adapter")
        return nil, "Version is required"
    end
    
    -- Normalize version to supported adapter version
    local adapter_version = AdapterFactory.get_adapter_version(version)
    if not adapter_version then
        utils.log("ERROR", "Unsupported Dify version: " .. version)
        return nil, "Unsupported version: " .. version
    end
    
    -- Get adapter module path
    local adapter_module_path = ADAPTERS[adapter_version]
    if not adapter_module_path then
        utils.log("ERROR", "No adapter available for version: " .. adapter_version)
        return nil, "No adapter available for version: " .. adapter_version
    end
    
    -- Load adapter module
    local success, adapter_module = pcall(require, adapter_module_path)
    if not success then
        utils.log("ERROR", "Failed to load adapter module: " .. adapter_module_path .. " - " .. tostring(adapter_module))
        return nil, "Failed to load adapter module: " .. tostring(adapter_module)
    end
    
    -- Create adapter instance
    local adapter_success, adapter_instance = pcall(adapter_module.new, config)
    if not adapter_success then
        utils.log("ERROR", "Failed to create adapter instance: " .. tostring(adapter_instance))
        return nil, "Failed to create adapter instance: " .. tostring(adapter_instance)
    end
    
    utils.log("INFO", string.format("Created adapter for version %s (using %s adapter)", version, adapter_version))
    return adapter_instance, nil
end

-- Get compatible adapter version for given Dify version
function AdapterFactory.get_adapter_version(version)
    if not version then
        return nil
    end
    
    -- Direct match
    if VERSION_COMPATIBILITY[version] then
        return VERSION_COMPATIBILITY[version]
    end
    
    -- Try to find compatible version by major.minor
    local major, minor = version:match("^(%d+)%.(%d+)")
    if major and minor then
        local major_num = tonumber(major)
        local minor_num = tonumber(minor)
        
        -- For v0.15.x series
        if major_num == 0 and minor_num == 15 then
            return "0.15.8"
        end
        
        -- For v1.x series
        if major_num == 1 then
            return "1.7.0"
        end
    end
    
    return nil
end

-- Get all supported versions
function AdapterFactory.get_supported_versions()
    local versions = {}
    for version, _ in pairs(VERSION_COMPATIBILITY) do
        table.insert(versions, version)
    end
    
    -- Sort versions
    table.sort(versions, function(a, b)
        local a_parts = {}
        local b_parts = {}
        
        for part in a:gmatch("%d+") do
            table.insert(a_parts, tonumber(part))
        end
        
        for part in b:gmatch("%d+") do
            table.insert(b_parts, tonumber(part))
        end
        
        for i = 1, math.max(#a_parts, #b_parts) do
            local a_part = a_parts[i] or 0
            local b_part = b_parts[i] or 0
            
            if a_part ~= b_part then
                return a_part < b_part
            end
        end
        
        return false
    end)
    
    return versions
end

-- Get available adapter types
function AdapterFactory.get_available_adapters()
    local adapters = {}
    for version, module_path in pairs(ADAPTERS) do
        table.insert(adapters, {
            version = version,
            module = module_path
        })
    end
    return adapters
end

-- Check if version is supported
function AdapterFactory.is_version_supported(version)
    return AdapterFactory.get_adapter_version(version) ~= nil
end

-- Get version compatibility info
function AdapterFactory.get_version_compatibility(version)
    local adapter_version = AdapterFactory.get_adapter_version(version)
    if not adapter_version then
        return nil
    end
    
    return {
        requested_version = version,
        adapter_version = adapter_version,
        module_path = ADAPTERS[adapter_version],
        is_exact_match = version == adapter_version
    }
end

-- Create adapter with automatic version detection
function AdapterFactory.create_adapter_with_detection(version_detector, config)
    if not version_detector then
        utils.log("ERROR", "Version detector is required")
        return nil, "Version detector is required"
    end
    
    -- Get detected version
    local detected_version = version_detector.detected_version
    if not detected_version then
        utils.log("ERROR", "No version detected by version detector")
        return nil, "No version detected"
    end
    
    -- Create adapter for detected version
    local adapter, error_msg = AdapterFactory.create_adapter(detected_version, config)
    if not adapter then
        return nil, error_msg
    end
    
    -- Add version detection info to adapter
    adapter.version_detection = version_detector:get_detection_summary()
    
    utils.log("INFO", string.format("Created adapter with automatic detection: %s (confidence: %.2f)", 
             detected_version, version_detector.confidence))
    
    return adapter, nil
end

-- Validate adapter configuration
function AdapterFactory.validate_adapter_config(version, config)
    local adapter_version = AdapterFactory.get_adapter_version(version)
    if not adapter_version then
        return false, "Unsupported version: " .. (version or "nil")
    end
    
    -- Create temporary adapter to validate config
    local adapter, error_msg = AdapterFactory.create_adapter(version, config)
    if not adapter then
        return false, error_msg
    end
    
    -- Validate configuration
    local success, validation_error = adapter:validate_config(config)
    if not success then
        return false, validation_error
    end
    
    return true, nil
end

-- Get adapter factory statistics
function AdapterFactory.get_statistics()
    return {
        supported_versions = #AdapterFactory.get_supported_versions(),
        available_adapters = #AdapterFactory.get_available_adapters(),
        version_mappings = utils.table_length(VERSION_COMPATIBILITY),
        adapter_modules = utils.table_length(ADAPTERS)
    }
end

-- Register new adapter (for extensibility)
function AdapterFactory.register_adapter(version, module_path)
    if not version or not module_path then
        utils.log("ERROR", "Version and module path are required to register adapter")
        return false
    end
    
    -- Test if module can be loaded
    local success, _ = pcall(require, module_path)
    if not success then
        utils.log("ERROR", "Cannot load adapter module: " .. module_path)
        return false
    end
    
    ADAPTERS[version] = module_path
    VERSION_COMPATIBILITY[version] = version
    
    utils.log("INFO", "Registered new adapter: " .. version .. " -> " .. module_path)
    return true
end

-- Unregister adapter
function AdapterFactory.unregister_adapter(version)
    if not version then
        return false
    end
    
    ADAPTERS[version] = nil
    
    -- Remove from compatibility mapping
    for v, adapter_v in pairs(VERSION_COMPATIBILITY) do
        if adapter_v == version then
            VERSION_COMPATIBILITY[v] = nil
        end
    end
    
    utils.log("INFO", "Unregistered adapter: " .. version)
    return true
end

-- Debug information
function AdapterFactory.debug_info()
    return {
        adapters = ADAPTERS,
        version_compatibility = VERSION_COMPATIBILITY,
        supported_versions = AdapterFactory.get_supported_versions(),
        statistics = AdapterFactory.get_statistics()
    }
end

return AdapterFactory


-- Simple Multi-Version Test for debugging

-- Set up package path
package.path = "./?.lua;./lib/?.lua;./test/?.lua;;" .. package.path

local utils = require("lib.utils")
local version_detector = require("lib.version_detector")
local adapter_factory = require("lib.adapters.adapter_factory")

print("=== Simple Multi-Version Test ===")

-- Test 1: Load modules
print("1. Testing module loading...")
local success = true

local modules = {
    "lib.utils",
    "lib.version_detector", 
    "lib.adapters.adapter_factory",
    "lib.adapters.base_adapter"
}

for _, module_name in ipairs(modules) do
    local ok, module = pcall(require, module_name)
    if ok then
        print("  ✓ " .. module_name .. " loaded successfully")
    else
        print("  ✗ " .. module_name .. " failed to load: " .. tostring(module))
        success = false
    end
end

if not success then
    print("Module loading failed, exiting...")
    os.exit(1)
end

-- Test 2: Version detection
print("\n2. Testing version detection...")
local detector = version_detector.new()

local test_contexts = {
    {
        name = "v0.15.8 header detection",
        context = {headers = {["x-dify-version"] = "0.15.8"}},
        expected = "0.15.8"
    },
    {
        name = "v1.7.0 header detection", 
        context = {headers = {["x-dify-version"] = "1.7.0"}},
        expected = "1.7.0"
    }
}

for _, test in ipairs(test_contexts) do
    local version, confidence = detector:detect_version(test.context)
    if version == test.expected then
        print("  ✓ " .. test.name .. " - detected: " .. version)
    else
        print("  ✗ " .. test.name .. " - expected: " .. test.expected .. ", got: " .. tostring(version))
        success = false
    end
end

-- Test 3: Adapter creation
print("\n3. Testing adapter creation...")
local adapter_tests = {
    {
        name = "v0.15.8 adapter",
        version = "0.15.8",
        config = {version = "0.15.8"}
    },
    {
        name = "v1.7.0 adapter",
        version = "1.7.0", 
        config = {version = "1.7.0"}
    }
}

for _, test in ipairs(adapter_tests) do
    local adapter, error_msg = adapter_factory.create_adapter(test.version, test.config)
    if adapter then
        print("  ✓ " .. test.name .. " created successfully")
    else
        print("  ✗ " .. test.name .. " failed: " .. tostring(error_msg))
        success = false
    end
end

-- Test 4: Basic functionality
print("\n4. Testing basic functionality...")
local v015_adapter = adapter_factory.create_adapter("0.15.8", {version = "0.15.8"})
local v1x_adapter = adapter_factory.create_adapter("1.7.0", {version = "1.7.0"})

if v015_adapter and v1x_adapter then
    -- Test basic request processing
    local test_data = {
        query = "Test email user@example.com"
    }
    local test_body = utils.json.encode(test_data)
    
    local v015_processed = v015_adapter:process_request("/v1/chat-messages", "POST", test_body, {})
    local v1x_processed = v1x_adapter:process_request("/v1/chat-messages", "POST", test_body, {})
    
    if v015_processed and v1x_processed then
        print("  ✓ Basic request processing works for both versions")
    else
        print("  ✗ Basic request processing failed")
        success = false
    end
else
    print("  ✗ Could not create adapters for testing")
    success = false
end

-- Test 5: Adapter factory statistics
print("\n5. Testing adapter factory statistics...")
local stats = adapter_factory.get_statistics()
print("  Supported versions: " .. stats.supported_versions)
print("  Available adapters: " .. stats.available_adapters)
print("  Version mappings: " .. stats.version_mappings)

if stats.supported_versions >= 2 then
    print("  ✓ Multiple versions supported")
else
    print("  ✗ Insufficient version support")
    success = false
end

-- Summary
print("\n=== Test Summary ===")
if success then
    print("🎉 All basic tests passed!")
    print("Multi-version support is working correctly.")
    os.exit(0)
else
    print("❌ Some tests failed!")
    print("Multi-version support needs fixes.")
    os.exit(1)
end


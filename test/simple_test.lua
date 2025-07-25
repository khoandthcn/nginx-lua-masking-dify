-- Simple test to debug issues
package.path = package.path .. ";../lib/?.lua;../?.lua"

print("=== Simple Debug Test ===")

-- Test 1: Load utils
print("1. Testing utils...")
local ok, utils = pcall(require, "utils")
if ok then
    print("✓ Utils loaded successfully")
else
    print("✗ Utils failed:", utils)
    return
end

-- Test 2: Load pattern_matcher
print("2. Testing pattern_matcher...")
local ok, pattern_matcher = pcall(require, "pattern_matcher")
if ok then
    print("✓ Pattern matcher loaded successfully")
else
    print("✗ Pattern matcher failed:", pattern_matcher)
    return
end

-- Test 3: Create pattern matcher instance
print("3. Testing pattern matcher creation...")
local config = {
    email = {
        enabled = true,
        regex = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+%.[a-zA-Z][a-zA-Z]+",
        placeholder_prefix = "EMAIL"
    }
}
local ok, matcher = pcall(pattern_matcher.new, config)
if ok and matcher then
    print("✓ Pattern matcher created successfully")
else
    print("✗ Pattern matcher creation failed:", matcher)
    return
end

-- Test 4: Test basic functionality
print("4. Testing basic masking...")
local text = "Email: test@example.com"
local ok, result = pcall(matcher.mask_text, matcher, text)
if ok then
    print("✓ Basic masking works:", result)
else
    print("✗ Basic masking failed:", result)
    return
end

-- Test 5: Load json_processor
print("5. Testing json_processor...")
local ok, json_processor = pcall(require, "json_processor")
if ok then
    print("✓ JSON processor loaded successfully")
else
    print("✗ JSON processor failed:", json_processor)
    return
end

-- Test 6: Create json processor instance
print("6. Testing json processor creation...")
local ok, processor = pcall(json_processor.new, matcher, {})
if ok and processor then
    print("✓ JSON processor created successfully")
else
    print("✗ JSON processor creation failed:", processor)
    return
end

-- Test 7: Load masking_plugin
print("7. Testing masking_plugin...")
local ok, masking_plugin = pcall(require, "masking_plugin")
if ok then
    print("✓ Masking plugin loaded successfully")
else
    print("✗ Masking plugin failed:", masking_plugin)
    return
end

-- Test 8: Create plugin instance
print("8. Testing plugin creation...")
local ok, plugin = pcall(masking_plugin.new)
if ok and plugin then
    print("✓ Plugin created successfully")
else
    print("✗ Plugin creation failed:", plugin)
    return
end

print("=== All tests passed! ===")


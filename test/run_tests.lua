#!/usr/bin/env lua

-- run_tests.lua - Test runner script for nginx-lua-masking plugin
-- Author: Manus AI
-- Version: 1.0.0

-- Add lib path
package.path = "./?.lua;../?.lua;../lib/?.lua;;" .. package.path

local test_runner = require("test.test_runner")

-- Function to run all test files
local function run_all_tests()
    print("Starting Nginx Lua Masking Plugin Test Suite")
    print("=" .. string.rep("=", 50))
    
    -- Reset test runner
    test_runner.reset()
    
    -- Load and run all test files
    local test_files = {
        "test_patterns",
        "test_json", 
        "test_integration"
    }
    
    print("Loading test files...")
    for _, test_file in ipairs(test_files) do
        local ok, err = pcall(require, test_file)
        if not ok then
            print("Error loading " .. test_file .. ": " .. err)
            return false
        else
            print("✓ Loaded " .. test_file)
        end
    end
    
    print("\nRunning tests...")
    print("=" .. string.rep("=", 50))
    
    -- Run all tests
    local success = test_runner.run_all_tests()
    
    -- Generate test report
    local report = test_runner.generate_report("test_report.json")
    
    print("\n" .. string.rep("=", 50))
    if success then
        print("🎉 ALL TESTS PASSED!")
        return true
    else
        print("❌ SOME TESTS FAILED!")
        return false
    end
end

-- Main execution
if arg and arg[0] and arg[0]:match("run_tests%.lua$") then
    local success = run_all_tests()
    os.exit(success and 0 or 1)
else
    -- Return module for require
    return {
        run_all_tests = run_all_tests
    }
end


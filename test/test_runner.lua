-- test_runner.lua - Test framework for nginx-lua-masking plugin
-- Author: Manus AI
-- Version: 1.0.0

-- Add lib path for testing
package.path = package.path .. ";../lib/?.lua"

local _M = {}

-- Test results storage
local test_results = {
    total_tests = 0,
    passed_tests = 0,
    failed_tests = 0,
    skipped_tests = 0,
    test_cases = {},
    start_time = 0,
    end_time = 0
}

-- Test suite registry
local test_suites = {}

-- Current test context
local current_suite = nil
local current_test = nil

-- Color codes for output
local colors = {
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m",
    white = "\27[37m",
    reset = "\27[0m"
}

-- Utility functions
local function colorize(text, color)
    if colors[color] then
        return colors[color] .. text .. colors.reset
    end
    return text
end

local function print_header(text)
    print(colorize("=" .. string.rep("=", #text + 2) .. "=", "blue"))
    print(colorize("| " .. text .. " |", "blue"))
    print(colorize("=" .. string.rep("=", #text + 2) .. "=", "blue"))
end

local function print_section(text)
    print(colorize("\n--- " .. text .. " ---", "cyan"))
end

-- Test framework functions

-- Register a test suite
function _M.describe(name, func)
    local suite = {
        name = name,
        tests = {},
        setup = nil,
        teardown = nil,
        before_each = nil,
        after_each = nil
    }
    
    current_suite = suite
    func()  -- Execute the suite definition
    current_suite = nil
    
    table.insert(test_suites, suite)
end

-- Register a test case
function _M.it(description, func)
    if not current_suite then
        error("Test case must be defined within a test suite")
    end
    
    local test_case = {
        description = description,
        func = func,
        status = "pending"
    }
    
    table.insert(current_suite.tests, test_case)
end

-- Setup function for test suite
function _M.setup(func)
    if not current_suite then
        error("Setup must be defined within a test suite")
    end
    current_suite.setup = func
end

-- Teardown function for test suite
function _M.teardown(func)
    if not current_suite then
        error("Teardown must be defined within a test suite")
    end
    current_suite.teardown = func
end

-- Before each test function
function _M.before_each(func)
    if not current_suite then
        error("Before each must be defined within a test suite")
    end
    current_suite.before_each = func
end

-- After each test function
function _M.after_each(func)
    if not current_suite then
        error("After each must be defined within a test suite")
    end
    current_suite.after_each = func
end

-- Assertion functions
function _M.assert_equal(actual, expected, message)
    message = message or ("Expected " .. tostring(expected) .. " but got " .. tostring(actual))
    if actual ~= expected then
        error(message)
    end
end

function _M.assert_not_equal(actual, expected, message)
    message = message or ("Expected not to equal " .. tostring(expected) .. " but got " .. tostring(actual))
    if actual == expected then
        error(message)
    end
end

function _M.assert_true(value, message)
    message = message or ("Expected true but got " .. tostring(value))
    if value ~= true then
        error(message)
    end
end

function _M.assert_false(value, message)
    message = message or ("Expected false but got " .. tostring(value))
    if value ~= false then
        error(message)
    end
end

function _M.assert_nil(value, message)
    message = message or ("Expected nil but got " .. tostring(value))
    if value ~= nil then
        error(message)
    end
end

function _M.assert_not_nil(value, message)
    message = message or "Expected not nil but got nil"
    if value == nil then
        error(message)
    end
end

function _M.assert_type(value, expected_type, message)
    local actual_type = type(value)
    message = message or ("Expected type " .. expected_type .. " but got " .. actual_type)
    if actual_type ~= expected_type then
        error(message)
    end
end

function _M.assert_match(string, pattern, message)
    message = message or ("Expected '" .. string .. "' to match pattern '" .. pattern .. "'")
    if not string:match(pattern) then
        error(message)
    end
end

function _M.assert_not_match(string, pattern, message)
    message = message or ("Expected '" .. string .. "' not to match pattern '" .. pattern .. "'")
    if string:match(pattern) then
        error(message)
    end
end

function _M.assert_contains(table, value, message)
    message = message or ("Expected table to contain " .. tostring(value))
    for _, v in pairs(table) do
        if v == value then
            return
        end
    end
    error(message)
end

function _M.assert_error(func, expected_error, message)
    local ok, err = pcall(func)
    if ok then
        error(message or "Expected function to throw an error")
    end
    if expected_error and not string.find(err, expected_error) then
        error(message or ("Expected error containing '" .. expected_error .. "' but got '" .. err .. "'"))
    end
end

-- Test execution functions
local function run_test_case(suite, test_case)
    current_test = test_case
    test_results.total_tests = test_results.total_tests + 1
    
    local start_time = os.clock()
    
    -- Run before_each if defined
    if suite.before_each then
        local ok, err = pcall(suite.before_each)
        if not ok then
            test_case.status = "failed"
            test_case.error = "Before each failed: " .. err
            test_case.duration = os.clock() - start_time
            test_results.failed_tests = test_results.failed_tests + 1
            return
        end
    end
    
    -- Run the test
    local ok, err = pcall(test_case.func)
    
    -- Run after_each if defined
    if suite.after_each then
        local after_ok, after_err = pcall(suite.after_each)
        if not after_ok then
            print(colorize("Warning: After each failed: " .. after_err, "yellow"))
        end
    end
    
    test_case.duration = os.clock() - start_time
    
    if ok then
        test_case.status = "passed"
        test_results.passed_tests = test_results.passed_tests + 1
        print(colorize("  ✓ " .. test_case.description, "green") .. 
              colorize(" (" .. string.format("%.3f", test_case.duration) .. "s)", "white"))
    else
        test_case.status = "failed"
        test_case.error = err
        test_results.failed_tests = test_results.failed_tests + 1
        print(colorize("  ✗ " .. test_case.description, "red"))
        print(colorize("    Error: " .. err, "red"))
    end
    
    current_test = nil
end

local function run_test_suite(suite)
    print_section(suite.name)
    
    -- Run setup if defined
    if suite.setup then
        local ok, err = pcall(suite.setup)
        if not ok then
            print(colorize("Suite setup failed: " .. err, "red"))
            return
        end
    end
    
    -- Run all test cases
    for _, test_case in ipairs(suite.tests) do
        run_test_case(suite, test_case)
        table.insert(test_results.test_cases, {
            suite = suite.name,
            description = test_case.description,
            status = test_case.status,
            duration = test_case.duration,
            error = test_case.error
        })
    end
    
    -- Run teardown if defined
    if suite.teardown then
        local ok, err = pcall(suite.teardown)
        if not ok then
            print(colorize("Suite teardown failed: " .. err, "yellow"))
        end
    end
end

-- Run all tests
function _M.run_all_tests()
    print_header("Running Nginx Lua Masking Plugin Tests")
    
    test_results.start_time = os.time()
    
    for _, suite in ipairs(test_suites) do
        run_test_suite(suite)
    end
    
    test_results.end_time = os.time()
    
    -- Print summary
    print_section("Test Summary")
    
    local duration = test_results.end_time - test_results.start_time
    print("Total time: " .. duration .. " seconds")
    print("Total tests: " .. test_results.total_tests)
    print(colorize("Passed: " .. test_results.passed_tests, "green"))
    print(colorize("Failed: " .. test_results.failed_tests, "red"))
    print(colorize("Skipped: " .. test_results.skipped_tests, "yellow"))
    
    local success_rate = test_results.total_tests > 0 and 
                        (test_results.passed_tests / test_results.total_tests * 100) or 0
    print("Success rate: " .. string.format("%.1f", success_rate) .. "%")
    
    if test_results.failed_tests > 0 then
        print_section("Failed Tests")
        for _, test_case in ipairs(test_results.test_cases) do
            if test_case.status == "failed" then
                print(colorize(test_case.suite .. " > " .. test_case.description, "red"))
                print(colorize("  " .. test_case.error, "red"))
            end
        end
    end
    
    return test_results.failed_tests == 0
end

-- Generate test report
function _M.generate_report(filename)
    filename = filename or "test_report.json"
    
    local report = {
        summary = {
            total_tests = test_results.total_tests,
            passed_tests = test_results.passed_tests,
            failed_tests = test_results.failed_tests,
            skipped_tests = test_results.skipped_tests,
            success_rate = test_results.total_tests > 0 and 
                          (test_results.passed_tests / test_results.total_tests * 100) or 0,
            duration = test_results.end_time - test_results.start_time,
            timestamp = os.date("%Y-%m-%d %H:%M:%S", test_results.start_time)
        },
        test_cases = test_results.test_cases,
        suites = {}
    }
    
    -- Group test cases by suite
    for _, suite in ipairs(test_suites) do
        local suite_info = {
            name = suite.name,
            total_tests = #suite.tests,
            passed_tests = 0,
            failed_tests = 0,
            tests = {}
        }
        
        for _, test_case in ipairs(suite.tests) do
            if test_case.status == "passed" then
                suite_info.passed_tests = suite_info.passed_tests + 1
            elseif test_case.status == "failed" then
                suite_info.failed_tests = suite_info.failed_tests + 1
            end
            
            table.insert(suite_info.tests, {
                description = test_case.description,
                status = test_case.status,
                duration = test_case.duration,
                error = test_case.error
            })
        end
        
        table.insert(report.suites, suite_info)
    end
    
    -- Write report to file
    local file = io.open(filename, "w")
    if file then
        -- Simple JSON encoding
        local function encode_json(obj)
            if type(obj) == "table" then
                local result = "{"
                local first = true
                for k, v in pairs(obj) do
                    if not first then result = result .. "," end
                    result = result .. '"' .. tostring(k) .. '":' .. encode_json(v)
                    first = false
                end
                return result .. "}"
            elseif type(obj) == "string" then
                return '"' .. obj:gsub('"', '\\"') .. '"'
            elseif type(obj) == "number" then
                return tostring(obj)
            elseif type(obj) == "boolean" then
                return tostring(obj)
            else
                return "null"
            end
        end
        
        file:write(encode_json(report))
        file:close()
        print("Test report saved to: " .. filename)
    else
        print(colorize("Failed to save test report to: " .. filename, "red"))
    end
    
    return report
end

-- Reset test results (for multiple test runs)
function _M.reset()
    test_results = {
        total_tests = 0,
        passed_tests = 0,
        failed_tests = 0,
        skipped_tests = 0,
        test_cases = {},
        start_time = 0,
        end_time = 0
    }
    test_suites = {}
end

-- Export main functions
_M.run_all_tests = run_all_tests
_M.run_test_suite = run_test_suite
_M.register_suite = register_suite
_M.get_results = get_results
_M.reset_results = reset_results

-- Export global functions for convenience
_G.describe = _M.describe
_G.it = _M.it
_G.setup = _M.setup
_G.teardown = _M.teardown
_G.before_each = _M.before_each
_G.after_each = _M.after_each

-- Export assertion functions
_G.assert_equal = _M.assert_equal
_G.assert_not_equal = _M.assert_not_equal
_G.assert_true = _M.assert_true
_G.assert_false = _M.assert_false
_G.assert_nil = _M.assert_nil
_G.assert_not_nil = _M.assert_not_nil
_G.assert_type = _M.assert_type
_G.assert_match = _M.assert_match
_G.assert_not_match = _M.assert_not_match
_G.assert_contains = _M.assert_contains
_G.assert_error = _M.assert_error

return _M
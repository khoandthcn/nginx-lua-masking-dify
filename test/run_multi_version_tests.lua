-- Multi-Version Test Runner
-- Runs integration tests for both Dify v0.15.8 and v1.7.0

local test_runner = require("test.test_runner")
local utils = require("lib.utils")

-- Import version-specific test suites
local dify_v015_tests = require("test.integration.test_dify_v0_15_integration")
local dify_v1x_tests = require("test.integration.test_dify_v1_x_integration")

local MultiVersionTestRunner = {}

function MultiVersionTestRunner.setup()
    utils.log("INFO", "Setting up multi-version test environment")
    
    -- Setup for both versions
    local v015_setup = dify_v015_tests.setup()
    local v1x_setup = dify_v1x_tests.setup()
    
    return v015_setup and v1x_setup
end

function MultiVersionTestRunner.teardown()
    utils.log("INFO", "Tearing down multi-version test environment")
    
    -- Teardown for both versions
    local v015_teardown = dify_v015_tests.teardown()
    local v1x_teardown = dify_v1x_tests.teardown()
    
    return v015_teardown and v1x_teardown
end

-- Test version compatibility between v0.15.8 and v1.7.0
function MultiVersionTestRunner.test_version_compatibility()
    local adapter_factory = require("lib.adapters.adapter_factory")
    
    -- Test that both versions are supported
    local v015_supported = adapter_factory.is_version_supported("0.15.8")
    local v1x_supported = adapter_factory.is_version_supported("1.7.0")
    
    test_runner.assert_true(v015_supported, "v0.15.8 should be supported")
    test_runner.assert_true(v1x_supported, "v1.7.0 should be supported")
    
    -- Test version compatibility mapping
    local v015_compat = adapter_factory.get_version_compatibility("0.15.8")
    local v1x_compat = adapter_factory.get_version_compatibility("1.7.0")
    
    test_runner.assert_not_nil(v015_compat, "Should have v0.15.8 compatibility info")
    test_runner.assert_not_nil(v1x_compat, "Should have v1.7.0 compatibility info")
    
    test_runner.assert_equal(v015_compat.adapter_version, "0.15.8", "Should map to correct adapter version")
    test_runner.assert_equal(v1x_compat.adapter_version, "1.7.0", "Should map to correct adapter version")
    
    return true
end

-- Test adapter factory statistics
function MultiVersionTestRunner.test_adapter_factory_stats()
    local adapter_factory = require("lib.adapters.adapter_factory")
    
    local stats = adapter_factory.get_statistics()
    
    test_runner.assert_true(stats.supported_versions >= 2, "Should support at least 2 versions")
    test_runner.assert_true(stats.available_adapters >= 2, "Should have at least 2 adapters")
    test_runner.assert_true(stats.version_mappings >= 2, "Should have at least 2 version mappings")
    
    utils.log("INFO", string.format("Adapter Factory Stats: %d versions, %d adapters, %d mappings", 
             stats.supported_versions, stats.available_adapters, stats.version_mappings))
    
    return true
end

-- Test cross-version data consistency
function MultiVersionTestRunner.test_cross_version_consistency()
    local adapter_factory = require("lib.adapters.adapter_factory")
    
    -- Create adapters for both versions
    local v015_adapter = adapter_factory.create_adapter("0.15.8", {version = "0.15.8"})
    local v1x_adapter = adapter_factory.create_adapter("1.7.0", {version = "1.7.0"})
    
    test_runner.assert_not_nil(v015_adapter, "Should create v0.15.8 adapter")
    test_runner.assert_not_nil(v1x_adapter, "Should create v1.7.0 adapter")
    
    -- Test that both adapters handle basic masking consistently
    local test_data = {
        query = "Email admin@test.com from IP 192.168.1.1"
    }
    
    local test_body = utils.json.encode(test_data)
    
    local v015_processed = v015_adapter:process_request("/v1/chat-messages", "POST", test_body, {})
    local v1x_processed = v1x_adapter:process_request("/v1/chat-messages", "POST", test_body, {})
    
    test_runner.assert_not_nil(v015_processed, "v0.15.8 should process request")
    test_runner.assert_not_nil(v1x_processed, "v1.7.0 should process request")
    
    -- Both should produce valid JSON
    local v015_data = utils.json.decode(v015_processed)
    local v1x_data = utils.json.decode(v1x_processed)
    
    test_runner.assert_not_nil(v015_data, "v0.15.8 should produce valid JSON")
    test_runner.assert_not_nil(v1x_data, "v1.7.0 should produce valid JSON")
    
    return true
end

-- Test performance comparison between versions
function MultiVersionTestRunner.test_performance_comparison()
    local adapter_factory = require("lib.adapters.adapter_factory")
    
    local v015_adapter = adapter_factory.create_adapter("0.15.8", {version = "0.15.8"})
    local v1x_adapter = adapter_factory.create_adapter("1.7.0", {version = "1.7.0"})
    
    local test_body = utils.json.encode({
        query = "Test email user@example.com and IP 10.0.0.1"
    })
    
    local iterations = 50
    
    -- Test v0.15.8 performance
    local v015_start = os.clock()
    for i = 1, iterations do
        v015_adapter:process_request("/v1/chat-messages", "POST", test_body, {})
    end
    local v015_duration = os.clock() - v015_start
    local v015_avg = v015_duration / iterations
    
    -- Test v1.7.0 performance
    local v1x_start = os.clock()
    for i = 1, iterations do
        v1x_adapter:process_request("/v1/chat-messages", "POST", test_body, {})
    end
    local v1x_duration = os.clock() - v1x_start
    local v1x_avg = v1x_duration / iterations
    
    utils.log("INFO", string.format("Performance Comparison:"))
    utils.log("INFO", string.format("  v0.15.8: %.3fms avg (%.3fs total)", v015_avg * 1000, v015_duration))
    utils.log("INFO", string.format("  v1.7.0:  %.3fms avg (%.3fs total)", v1x_avg * 1000, v1x_duration))
    
    -- Both should be reasonably fast
    test_runner.assert_true(v015_avg < 0.02, "v0.15.8 should be under 20ms")
    test_runner.assert_true(v1x_avg < 0.03, "v1.7.0 should be under 30ms (allows for enhanced features)")
    
    return true
end

-- Test version detection accuracy
function MultiVersionTestRunner.test_version_detection_accuracy()
    local version_detector = require("lib.version_detector")
    local detector = version_detector.new()
    
    -- Test v0.15.8 detection scenarios
    local v015_scenarios = {
        {
            context = {headers = {["x-dify-version"] = "0.15.8"}},
            expected = "0.15.8"
        },
        {
            context = {headers = {["user-agent"] = "Dify/0.15.8"}},
            expected = "0.15.8"
        }
    }
    
    -- Test v1.7.0 detection scenarios
    local v1x_scenarios = {
        {
            context = {headers = {["x-dify-version"] = "1.7.0"}},
            expected = "1.7.0"
        },
        {
            context = {headers = {["user-agent"] = "Dify/1.7.0"}},
            expected = "1.7.0"
        }
    }
    
    -- Test all scenarios
    for i, scenario in ipairs(v015_scenarios) do
        local version, confidence = detector:detect_version(scenario.context)
        test_runner.assert_equal(version, scenario.expected, 
                               string.format("v0.15.8 scenario %d should detect correctly", i))
        test_runner.assert_true(confidence > 0.7, 
                               string.format("v0.15.8 scenario %d should have good confidence", i))
    end
    
    for i, scenario in ipairs(v1x_scenarios) do
        local version, confidence = detector:detect_version(scenario.context)
        test_runner.assert_equal(version, scenario.expected, 
                               string.format("v1.7.0 scenario %d should detect correctly", i))
        test_runner.assert_true(confidence > 0.7, 
                               string.format("v1.7.0 scenario %d should have good confidence", i))
    end
    
    return true
end

-- Test feature matrix between versions
function MultiVersionTestRunner.test_feature_matrix()
    local adapter_factory = require("lib.adapters.adapter_factory")
    
    local v015_adapter = adapter_factory.create_adapter("0.15.8", {version = "0.15.8"})
    local v1x_adapter = adapter_factory.create_adapter("1.7.0", {version = "1.7.0"})
    
    local v015_features = v015_adapter:get_features()
    local v1x_features = v1x_adapter:get_features()
    
    -- Features that should be consistent across versions
    local common_features = {"streaming_mode", "basic_masking"}
    for _, feature in ipairs(common_features) do
        test_runner.assert_equal(v015_features[feature], v1x_features[feature], 
                               "Common feature should be consistent: " .. feature)
    end
    
    -- Features that should be different
    local v1x_only_features = {"oauth_support", "file_upload", "enhanced_metadata"}
    for _, feature in ipairs(v1x_only_features) do
        test_runner.assert_false(v015_features[feature] or false, 
                               "v0.15.8 should not have v1.x feature: " .. feature)
        test_runner.assert_true(v1x_features[feature] or false, 
                               "v1.7.0 should have enhanced feature: " .. feature)
    end
    
    utils.log("INFO", "Feature Matrix Validation:")
    utils.log("INFO", string.format("  v0.15.8 features: %d", utils.table_length(v015_features)))
    utils.log("INFO", string.format("  v1.7.0 features:  %d", utils.table_length(v1x_features)))
    
    return true
end

-- Run comprehensive multi-version test suite
function MultiVersionTestRunner.run_comprehensive_tests()
    utils.log("INFO", "Starting comprehensive multi-version test suite")
    
    local results = {
        total_tests = 0,
        passed_tests = 0,
        failed_tests = 0,
        test_results = {}
    }
    
    -- Setup test environment
    if not MultiVersionTestRunner.setup() then
        utils.log("ERROR", "Failed to setup multi-version test environment")
        return results
    end
    
    -- Run multi-version compatibility tests
    local multi_version_tests = {
        "test_version_compatibility",
        "test_adapter_factory_stats",
        "test_cross_version_consistency",
        "test_performance_comparison",
        "test_version_detection_accuracy",
        "test_feature_matrix"
    }
    
    utils.log("INFO", "Running multi-version compatibility tests...")
    local multi_results = test_runner.run_test_suite("Multi-Version Compatibility Tests", 
                                                    MultiVersionTestRunner, multi_version_tests)
    
    -- Run v0.15.8 specific tests
    utils.log("INFO", "Running Dify v0.15.8 integration tests...")
    local v015_results = dify_v015_tests.run_all_tests()
    
    -- Run v1.7.0 specific tests
    utils.log("INFO", "Running Dify v1.7.0 integration tests...")
    local v1x_results = dify_v1x_tests.run_all_tests()
    
    -- Combine results
    results.total_tests = multi_results.total_tests + v015_results.total_tests + v1x_results.total_tests
    results.passed_tests = multi_results.passed_tests + v015_results.passed_tests + v1x_results.passed_tests
    results.failed_tests = multi_results.failed_tests + v015_results.failed_tests + v1x_results.failed_tests
    
    results.test_results = {
        multi_version = multi_results,
        dify_v015 = v015_results,
        dify_v1x = v1x_results
    }
    
    -- Calculate success rate
    local success_rate = (results.passed_tests / results.total_tests) * 100
    
    -- Generate summary
    utils.log("INFO", "=== MULTI-VERSION TEST SUMMARY ===")
    utils.log("INFO", string.format("Total Tests: %d", results.total_tests))
    utils.log("INFO", string.format("Passed: %d", results.passed_tests))
    utils.log("INFO", string.format("Failed: %d", results.failed_tests))
    utils.log("INFO", string.format("Success Rate: %.1f%%", success_rate))
    utils.log("INFO", "")
    utils.log("INFO", "Test Suite Breakdown:")
    utils.log("INFO", string.format("  Multi-Version: %d/%d passed", multi_results.passed_tests, multi_results.total_tests))
    utils.log("INFO", string.format("  Dify v0.15.8: %d/%d passed", v015_results.passed_tests, v015_results.total_tests))
    utils.log("INFO", string.format("  Dify v1.7.0:  %d/%d passed", v1x_results.passed_tests, v1x_results.total_tests))
    
    if results.failed_tests > 0 then
        utils.log("WARN", string.format("❌ %d tests failed", results.failed_tests))
    else
        utils.log("INFO", "🎉 All tests passed!")
    end
    
    -- Cleanup
    MultiVersionTestRunner.teardown()
    
    return results
end

-- Save test results to file
function MultiVersionTestRunner.save_test_results(results, filename)
    local report = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        plugin_version = "2.0.0",
        test_summary = {
            total_tests = results.total_tests,
            passed_tests = results.passed_tests,
            failed_tests = results.failed_tests,
            success_rate = (results.passed_tests / results.total_tests) * 100
        },
        test_suites = {
            multi_version_compatibility = {
                total = results.test_results.multi_version.total_tests,
                passed = results.test_results.multi_version.passed_tests,
                failed = results.test_results.multi_version.failed_tests
            },
            dify_v015_integration = {
                total = results.test_results.dify_v015.total_tests,
                passed = results.test_results.dify_v015.passed_tests,
                failed = results.test_results.dify_v015.failed_tests
            },
            dify_v1x_integration = {
                total = results.test_results.dify_v1x.total_tests,
                passed = results.test_results.dify_v1x.passed_tests,
                failed = results.test_results.dify_v1x.failed_tests
            }
        },
        supported_versions = {
            "0.15.8",
            "1.7.0"
        },
        features_tested = {
            basic_masking = true,
            streaming_support = true,
            oauth_support = true,
            file_upload = true,
            enhanced_metadata = true,
            version_detection = true,
            performance = true,
            error_handling = true
        }
    }
    
    local report_json = utils.json.encode(report)
    local file = io.open(filename, "w")
    if file then
        file:write(report_json)
        file:close()
        utils.log("INFO", "Test results saved to: " .. filename)
        return true
    else
        utils.log("ERROR", "Failed to save test results to: " .. filename)
        return false
    end
end

-- Main execution
if arg and arg[0] and arg[0]:match("run_multi_version_tests%.lua$") then
    utils.log("INFO", "Starting Multi-Version Test Runner...")
    
    local results = MultiVersionTestRunner.run_comprehensive_tests()
    
    -- Save results
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local report_file = string.format("multi_version_test_report_%s.json", timestamp)
    MultiVersionTestRunner.save_test_results(results, report_file)
    
    -- Exit with appropriate code
    if results.failed_tests > 0 then
        os.exit(1)
    else
        os.exit(0)
    end
end

return MultiVersionTestRunner


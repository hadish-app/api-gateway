# API Gateway Testing Guide

## Overview

The API Gateway uses a custom testing framework designed for OpenResty/Lua applications, with support for lifecycle hooks, state management, and comprehensive assertions.

## Directory Structure

```
tests/
├── core/                   # Core testing framework
│   ├── test_utils.lua     # Testing utilities and assertions
│   └── test_runner.lua    # Test discovery and runner
├── modules/               # Module tests
│   ├── middleware/       # Middleware component tests
│   │   ├── cors_test.lua
│   │   ├── request_id_test.lua
│   │   └── registry_test.lua
│   ├── core/            # Core functionality tests
│   │   ├── middleware_chain_test.lua
│   │   └── phase_handlers_test.lua
│   └── utils/           # Utility function tests
│       └── env_test.lua
└── template_test.lua     # Standard test template
```

## Test Structure

Each test file follows our standard template structure:

```lua
-- 1. Requires
local test_utils = require "tests.core.test_utils"

-- 2. Local helper functions
local function setup_test_environment()
    test_utils.reset_state()
    -- Add any other setup needed
end

-- 3. Module definition
local _M = {}

-- 4. Test lifecycle hooks (optional)
function _M.before_all()
    -- Run once before all tests
end

function _M.before_each()
    -- Run before each test
    setup_test_environment()
end

-- 5. Test cases
_M.tests = {
    {
        name = "Test: Description of test case",
        func = function()
            -- Test implementation
        end
    }
}

-- 6. Test cleanup hooks (optional)
function _M.after_each()
    -- Run after each test
end

function _M.after_all()
    -- Run once after all tests
end

return _M
```

## Writing Tests

### Test Case Structure

Our test cases follow several common patterns based on the type of functionality being tested:

1. **Simple Function Tests**

```lua
{
    name = "Test: Convert value with various inputs",
    func = function()
        -- Single assertion tests
        test_utils.assert_equals(123, type_conversion.to_number("123"),
            "Should convert number string")
        test_utils.assert_equals(true, type_conversion.to_boolean("true"),
            "Should convert boolean string")
        test_utils.assert_equals(nil, type_conversion.to_boolean("invalid"),
            "Should handle invalid input")
    end
}
```

2. **Multi-Phase Middleware Tests**

```lua
{
    name = "Test: CORS request handling",
    func = function()
        -- Setup
        setup_test_environment()
        mock_request({
            headers = { Origin = "https://allowed-origin.com" }
        })

        -- Execute and verify access phase
        local access_result = cors.access:handle()
        test_utils.assert_true(access_result, "Access handler should return true")
        test_utils.assert_not_nil(ngx.ctx.cors, "CORS context should be set")

        -- Execute and verify header filter phase
        local header_result = cors.header_filter:handle()
        test_utils.assert_true(header_result, "Header filter should return true")
        test_utils.assert_equals(
            ngx.header["Access-Control-Allow-Origin"],
            "https://allowed-origin.com",
            "Origin should be allowed"
        )
    end
}
```

3. **Data Structure Validation Tests**

```lua
{
    name = "Test: Health check data structure",
    func = function()
        -- Get data
        local data = health.get_detailed_health()

        -- Validate structure
        test_utils.assert_equals("table", type(data), "Health data should be a table")
        test_utils.assert_equals("string", type(data.status), "Status should be a string")
        test_utils.assert_equals("healthy", data.status, "Status should be 'healthy'")

        -- Validate nested structures
        test_utils.assert_equals("table", type(data.system), "System should be a table")
        test_utils.assert_equals("string", type(data.system.hostname), "Hostname should be a string")

        -- Validate metrics
        test_utils.assert_equals("table", type(data.performance), "Performance should be a table")
        test_utils.assert_equals("number", type(data.performance.request_time),
            "Request time should be a number")
    end
}
```

4. **State Management Tests**

```lua
{
    name = "Test: Middleware state transitions",
    func = function()
        -- Setup
        setup_test_environment()
        local middleware = create_test_middleware("test_middleware", 10)

        -- Test initial state
        test_utils.assert_equals(0, middleware.execution_count,
            "Initial execution count should be zero")

        -- Test state change
        middleware_chain.set_state("test_middleware", middleware_chain.STATES.ACTIVE)
        middleware_chain.run("/")
        test_utils.assert_equals(1, middleware.execution_count,
            "Middleware should execute when active")

        -- Test state persistence
        middleware_chain.set_state("test_middleware", middleware_chain.STATES.DISABLED)
        middleware_chain.run("/")
        test_utils.assert_equals(1, middleware.execution_count,
            "Disabled middleware should not execute")
    end
}
```

5. **Security Tests**

```lua
{
    name = "Test: Input validation and sanitization",
    func = function()
        local malicious_inputs = {
            -- SQL Injection attempts
            "1234'; DROP TABLE users; --",
            -- XSS attempts
            "<script>alert('xss')</script>",
            -- Path traversal attempts
            "../../../etc/passwd",
            -- Command injection attempts
            "$(rm -rf /)",
            -- Oversized/malformed input
            string.rep("a", 1024 * 1024),
            -- Special characters
            "🦄\0\n\r\t"
        }

        for _, input in ipairs(malicious_inputs) do
            local result = validate_input(input)
            test_utils.assert_false(result.valid,
                "Should reject malicious input: " .. input:sub(1, 32))
        end
    end
}
```

6. **Error Handling Tests**

```lua
{
    name = "Test: Error conditions",
    func = function()
        -- Test invalid input
        local ok, err = pcall(function()
            module.process_invalid_input()
        end)
        test_utils.assert_false(ok, "Should throw error for invalid input")
        test_utils.assert_not_nil(err, "Should provide error message")

        -- Test recovery
        local recovery_result = module.recover_from_error()
        test_utils.assert_true(recovery_result, "Should recover from error state")
    end
}
```

### Common Test Patterns

1. **Setup-Execute-Verify Pattern**

   - Setup: Prepare test environment and input data
   - Execute: Run the functionality being tested
   - Verify: Assert expected outcomes

2. **State Reset**

   - Always reset state before tests using `test_utils.reset_state()`
   - Clean up any test-specific state in `after_each`
   - Use `before_each` for common setup

3. **Comprehensive Assertions**

   - Test both positive and negative cases
   - Verify all relevant state changes
   - Include descriptive error messages

4. **Helper Functions**
   - Create reusable setup functions
   - Abstract common validation logic
   - Keep test cases focused and readable

### Available Assertions

The framework provides comprehensive assertions through `test_utils`:

```lua
-- Core assertions
test_utils.assert_equals(expected, actual, message)
test_utils.assert_not_equals(expected, actual, message)
test_utils.assert_not_nil(value, message)
test_utils.assert_nil(value, message)
test_utils.assert_true(value, message)
test_utils.assert_false(value, message)

-- Type assertions
test_utils.assert_type(value, expected_type, message)

-- Table assertions
test_utils.assert_table_equals(expected, actual, message)
```

### Test Environment

The test environment provides a mock Nginx context that can be reset between tests:

```lua
-- Available in tests
ngx.ctx = {}           -- Request context
ngx.var = {}          -- Nginx variables
ngx.header = {}       -- Response headers
ngx.shared = {        -- Shared dictionaries
    stats = {},
    metrics = {},
    rate_limit = {},
    config_cache = {}
}

-- Reset state between tests
test_utils.reset_state()  -- Resets ngx.ctx, headers, and shared dicts
```

## Running Tests

### Individual Test File

```bash
# Run specific test file
curl http://localhost:8080/tests/modules/middleware/request_id_test
```

Example output:

```
Running test suite: modules/middleware/request_id_test

Test: Request ID generation
✓ Should generate valid UUID
✓ Should set request ID in context

Test: Request ID header propagation
✓ Should set X-Request-ID header

Test Summary:
Total: 3
Passed: 3
Failed: 0
```

### All Tests

```bash
# Run all tests
curl http://localhost:8080/tests/all
```

The test runner will:

1. Discover all test files under `/tests/modules/`
2. Execute lifecycle hooks (before_all, before_each, after_each, after_all)
3. Run each test suite
4. Report overall results

## Test Categories and Examples

### 1. Middleware Tests

Tests for middleware components focus on request/response handling:

```lua
-- Example from cors_test.lua
{
    name = "Test: Simple CORS request with allowed origin",
    func = function()
        -- Setup
        setup_test_environment()
        mock_request({
            headers = { Origin = "https://allowed-origin.com" }
        })

        -- Execute access phase
        local access_result = cors.access:handle()

        -- Verify access phase
        test_utils.assert_true(access_result, "Access handler should return true")
        test_utils.assert_not_nil(ngx.ctx.cors, "CORS context should be set")
        test_utils.assert_equals(
            ngx.ctx.cors.origin,
            "https://allowed-origin.com",
            "Origin should be stored in context"
        )
    end
}
```

### 2. Core Component Tests

Tests for core functionality like phase handlers and middleware chains:

```lua
-- Example from phase_handlers_test.lua
{
    name = "Test: Init phase initialization",
    func = function()
        -- Execute init phase
        local ok, err = phase_handlers.init()

        -- Verify initialization
        test_utils.assert_true(ok, "Init phase should succeed")
        test_utils.assert_nil(err, "No error should be present")

        -- Verify shared dictionaries
        test_utils.assert_not_nil(ngx.shared.stats, "Stats dictionary should exist")
        test_utils.assert_not_nil(ngx.shared.metrics, "Metrics dictionary should exist")
    end
}
```

### 3. Utility Tests

Tests for utility functions with comprehensive input validation:

```lua
-- Example from type_conversion_test.lua
{
    name = "Test: Convert value with various inputs",
    func = function()
        test_utils.assert_equals(123, type_conversion.to_number("123"),
            "Should convert number string")
        test_utils.assert_equals(true, type_conversion.to_boolean("true"),
            "Should convert boolean string")
        test_utils.assert_equals(nil, type_conversion.to_boolean("invalid"),
            "Should handle invalid input")
    end
}
```

## Best Practices

1. **Test Organization**:

   - Follow the template structure consistently
   - Group related tests in the same file
   - Use descriptive test names
   - Keep tests focused and independent

2. **Test Setup**:

   - Use lifecycle hooks (before_all, before_each) for setup
   - Reset state between tests using `test_utils.reset_state()`
   - Mock external dependencies
   - Clean up resources in after_each/after_all hooks

3. **Assertions**:

   - Use appropriate assertions for the type being tested
   - Include descriptive error messages
   - Test both positive and negative cases
   - Verify state changes when applicable

4. **Error Handling**:
   - Test error conditions
   - Verify error messages
   - Test recovery paths
   - Handle cleanup in error cases

## Debugging Tests

1. **Logging**:

   ```lua
   ngx.log(ngx.DEBUG, "Test state: ", require("cjson").encode(ngx.ctx))
   ```

2. **State Inspection**:

   ```lua
   ngx.log(ngx.DEBUG, "Test phase: ", ngx.get_phase())
   ngx.log(ngx.DEBUG, "Context: ", require("cjson").encode(ngx.ctx))
   ```

3. **Test Configuration**:
   - Tests are configured in `configs/locations/test.conf`
   - Adjust buffer settings for large test output:
     ```nginx
     proxy_buffering off;
     proxy_buffer_size 512k;
     proxy_buffers 16 512k;
     proxy_busy_buffers_size 1m;
     client_body_buffer_size 1m;
     client_max_body_size 100m;
     ```
   - Enable debug logging for detailed information

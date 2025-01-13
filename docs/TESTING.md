# Testing Guide

## Overview

The API Gateway testing suite follows a standardized structure using a template-based approach. Each test file follows a consistent pattern that includes setup, test cases, and cleanup phases.

## Test Structure

```
tests/
├── core/                     # Core functionality tests
│   └── test_utils.lua       # Testing utilities
├── modules/                 # Module tests
│   └── middleware/         # Middleware tests
├── template_test.lua       # Test template file
└── README.md              # Testing documentation
```

## Test Template

Each test file follows this template structure:

```lua
-- 1. Requires
local test_utils = require "tests.core.test_utils"

-- 2. Local helper functions
local function setup_test_environment()
    -- Reset state
    test_utils.reset_state()
    -- Add any other setup needed
end

-- 3. Module definition
local _M = {}

-- 4. Test setup (optional)
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

-- 6. Test cleanup (optional)
function _M.after_each()
    -- Run after each test
end

function _M.after_all()
    -- Run once after all tests
end

return _M
```

## Test Categories

### 1. Core Tests

Tests for core functionality including:

- Phase handlers
- Middleware chain
- Utility functions
- State management

```lua
-- Example core test
local tests = {
    {
        name = "Test: State management",
        func = function()
            test_utils.reset_state()
            -- Test implementation
            test_utils.assert_state("expected_state")
        end
    }
}
```

### 2. Middleware Tests

Tests for middleware components:

- Registry functionality
- Individual middleware behavior
- Phase interactions
- Error handling

```lua
-- Example middleware test
local tests = {
    {
        name = "Test: Middleware registration",
        func = function()
            local registry = require "modules.middleware.registry"
            -- Test implementation
            test_utils.assert_true(result)
        end
    }
}
```

## Test Utilities

The `test_utils.lua` module provides common testing functions:

```lua
local test_utils = {
    reset_state = function()
        -- Reset test state
        ngx.ctx = {}
        -- Reset other state as needed
    end,

    assert_true = function(value, message)
        assert(value == true, message or "Expected true value")
    end,

    assert_equals = function(actual, expected, message)
        assert(actual == expected,
               message or string.format("Expected %s but got %s",
                                      tostring(expected),
                                      tostring(actual)))
    end
}
```

## Running Tests

### Individual Tests

```bash
# Run a specific test file
curl http://localhost:8080/test/modules/middleware/request_id_test
```

### Test Suite

```bash
# Run all tests
curl http://localhost:8080/test/run_all
```

## Best Practices

1. **Test Organization**:

   - Use descriptive test names
   - Group related tests
   - Follow template structure
   - Keep tests focused

2. **Test Setup**:

   - Reset state between tests
   - Use `before_each` for common setup
   - Clean up after tests
   - Isolate test cases

3. **Assertions**:

   - Use descriptive messages
   - Test edge cases
   - Verify state changes
   - Check error conditions

4. **Error Handling**:
   - Test error scenarios
   - Verify error messages
   - Check error propagation
   - Test recovery paths

## Example: Complete Test Case

```lua
-- Test suite for request ID middleware
local test_utils = require "tests.core.test_utils"
local request_id = require "modules.middleware.request_id"

local _M = {}

function _M.before_each()
    test_utils.reset_state()
end

_M.tests = {
    {
        name = "Test: Request ID generation",
        func = function()
            -- Setup
            ngx.ctx = {}

            -- Execute
            local result = request_id.access:handle()

            -- Verify
            test_utils.assert_true(result)
            test_utils.assert_not_nil(ngx.ctx.request_id)
        end
    },
    {
        name = "Test: Request ID header propagation",
        func = function()
            -- Setup
            ngx.ctx.request_id = "test-id"

            -- Execute
            local result = request_id.header_filter:handle()

            -- Verify
            test_utils.assert_true(result)
            test_utils.assert_equals(ngx.header["X-Request-ID"], "test-id")
        end
    }
}

return _M
```

## Debugging Tests

1. **Logging**:

   ```lua
   test_utils.log_debug("Test state: ", require("cjson").encode(ngx.ctx))
   ```

2. **State Inspection**:

   ```lua
   test_utils.dump_state = function()
       -- Log current test state
       ngx.log(ngx.DEBUG, "Test phase: ", ngx.get_phase())
       ngx.log(ngx.DEBUG, "Context: ", require("cjson").encode(ngx.ctx))
   end
   ```

3. **Error Tracking**:
   ```lua
   test_utils.track_errors = function(f)
       local ok, err = pcall(f)
       if not ok then
           ngx.log(ngx.ERR, "Test error: ", err)
           return false, err
       end
       return true
   end
   ```

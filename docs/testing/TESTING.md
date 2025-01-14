# Testing Guide

## Overview

The API Gateway testing suite follows a standardized structure using a template-based approach. Each test file follows a consistent pattern that includes setup, test cases, and cleanup phases.

## Test Structure

```
tests/
├── modules/                 # Module tests
│   └── middleware/         # Middleware tests
│       ├── request_id_test.lua
│       └── registry_test.lua
└── template_test.lua       # Test template file
```

## Test Template

Each test file follows this template structure:

```lua
-- 1. Requires
local test_utils = require "tests.core.test_utils"

-- 2. Local helper functions
local function setup_test_environment()
    -- Reset state
    ngx.ctx = {}
    -- Add any other setup needed
end

-- 3. Module definition
local _M = {}

-- 4. Test cases
_M.tests = {
    {
        name = "Test: Description of test case",
        func = function()
            -- Test implementation
        end
    }
}

return _M
```

## Test Categories

### 1. Middleware Tests

Tests for middleware components:

- Registry functionality
- Individual middleware behavior
- Phase interactions
- Basic error handling

```lua
-- Example middleware test
local tests = {
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
    }
}
```

## Test Utilities

The `test_utils` module provides common testing functions:

```lua
local test_utils = {
    assert_true = function(value, message)
        assert(value == true, message or "Expected true value")
    end,

    assert_equals = function(actual, expected, message)
        assert(actual == expected,
               message or string.format("Expected %s but got %s",
                                      tostring(expected),
                                      tostring(actual)))
    end,

    assert_not_nil = function(value, message)
        assert(value ~= nil, message or "Expected non-nil value")
    end
}
```

## Running Tests

### Individual Tests

```bash
# Run a specific test file
curl http://localhost:8080/tests/modules/middleware/request_id_test
```

### Test Suite

```bash
# Run all tests
curl http://localhost:8080/tests/run_all
```

## Best Practices

1. **Test Organization**:

   - Use descriptive test names
   - Group related tests
   - Follow template structure
   - Keep tests focused

2. **Test Setup**:

   - Reset state between tests
   - Clean up after tests
   - Isolate test cases

3. **Assertions**:

   - Use descriptive messages
   - Test edge cases
   - Verify state changes

4. **Error Handling**:
   - Test error scenarios
   - Verify error messages
   - Test recovery paths

## Example: Complete Test Case

```lua
-- Test suite for request ID middleware
local test_utils = require "tests.core.test_utils"
local request_id = require "modules.middleware.request_id"

local _M = {}

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
   ngx.log(ngx.DEBUG, "Test state: ", require("cjson").encode(ngx.ctx))
   ```

2. **State Inspection**:
   ```lua
   -- Log current test state
   ngx.log(ngx.DEBUG, "Test phase: ", ngx.get_phase())
   ngx.log(ngx.DEBUG, "Context: ", require("cjson").encode(ngx.ctx))
   ```

# Testing Guide

## Overview

The API Gateway uses a custom testing framework designed for OpenResty/Lua applications. This guide covers test organization, writing tests, and running tests.

## Test Organization

```
tests/
├── modules/                 # Module tests
│   ├── middleware/         # Middleware tests
│   │   ├── request_id_test.lua
│   │   └── registry_test.lua
│   └── services/          # Service tests
│       └── health_test.lua
└── test_utils.lua         # Testing utilities
```

## Test Structure

Each test file follows a standard structure:

```lua
-- 1. Required modules
local test_utils = require "tests.test_utils"
local module_to_test = require "modules.path.to.module"

-- 2. Module definition
local _M = {}

-- 3. Test cases
_M.tests = {
    {
        name = "Test: Description of what is being tested",
        func = function()
            -- Test implementation
        end
    }
}

return _M
```

## Writing Tests

### Basic Test Case

```lua
-- Simple test case
{
    name = "Test: Basic functionality",
    func = function()
        -- Setup
        local input = "test-input"

        -- Execute
        local result = module_to_test.process(input)

        -- Verify
        test_utils.assert_equals(result, "expected-output")
    end
}
```

### Testing Middleware

```lua
-- Middleware test case
{
    name = "Test: Middleware execution",
    func = function()
        -- Setup
        ngx.ctx = {}
        local middleware = require "modules.middleware.example"

        -- Execute
        local result = middleware:handle()

        -- Verify
        test_utils.assert_true(result)
        test_utils.assert_not_nil(ngx.ctx.example_data)
    end
}
```

### Testing Services

```lua
-- Service test case
{
    name = "Test: Health check service",
    func = function()
        -- Setup
        ngx.shared.stats:flush_all()
        local health = require "modules.services.health"

        -- Execute
        local status, data = health.check()

        -- Verify
        test_utils.assert_true(status)
        test_utils.assert_equals(data.status, "healthy")
    end
}
```

## Running Tests

### Individual Test File

```bash
# Run specific test file
curl http://localhost:8080/tests/modules/middleware/request_id_test
```

Example output:

```json
{
  "results": {
    "total": 3,
    "passed": 3,
    "failed": 0,
    "tests": [
      {
        "name": "Test: Request ID generation",
        "status": "passed",
        "duration": 0.001
      }
    ]
  }
}
```

### All Tests

```bash
# Run all tests
curl http://localhost:8080/tests/run_all
```

Example output:

```json
{
  "summary": {
    "total_files": 5,
    "total_tests": 15,
    "passed": 14,
    "failed": 1,
    "duration": 0.045
  },
  "failures": [
    {
      "file": "request_id_test.lua",
      "test": "Test: Invalid UUID handling",
      "error": "Expected false but got true"
    }
  ]
}
```

## Test Context

The test environment provides a mock Nginx context:

```lua
-- Available in tests
ngx.ctx = {}           -- Request context
ngx.var = {}          -- Nginx variables
ngx.req = {           -- Request object
    get_headers = function() return {} end,
    get_method = function() return "GET" end
}
ngx.shared = {        -- Shared dictionaries
    stats = {},
    cache = {}
}
```

## Mocking

### Request Headers

```lua
-- Mock request headers
ngx.req.get_headers = function()
    return {
        ["X-Request-ID"] = "test-id",
        ["Authorization"] = "Bearer token"
    }
end
```

### Shared Dictionaries

```lua
-- Mock shared dictionary
ngx.shared.stats = {
    get = function(key) return 0 end,
    set = function(key, value) return true end,
    incr = function(key, value) return value end
}
```

### Response Headers

```lua
-- Mock response headers
ngx.header = {}
```

## Best Practices

1. **Test Organization**:

   - Group related tests
   - Use descriptive names
   - Follow template structure
   - Keep tests focused

2. **Test Setup**:

   - Reset state before each test
   - Mock required dependencies
   - Isolate test cases
   - Clean up after tests

3. **Assertions**:

   - Use appropriate assertions
   - Include helpful messages
   - Test edge cases
   - Verify state changes

4. **Error Handling**:
   - Test error conditions
   - Verify error messages
   - Test recovery paths
   - Handle cleanup in errors

## Example: Complete Test File

```lua
-- tests/modules/middleware/rate_limit_test.lua
local test_utils = require "tests.test_utils"
local rate_limit = require "modules.middleware.rate_limit"

local _M = {}

-- Helper function
local function setup_test()
    ngx.shared.stats:flush_all()
    ngx.var = {
        binary_remote_addr = "192.168.1.1"
    }
end

_M.tests = {
    {
        name = "Test: Rate limit not exceeded",
        func = function()
            -- Setup
            setup_test()

            -- Execute
            local result = rate_limit:handle()

            -- Verify
            test_utils.assert_true(result)
            local count = ngx.shared.stats:get("192.168.1.1:rate")
            test_utils.assert_equals(count, 1)
        end
    },
    {
        name = "Test: Rate limit exceeded",
        func = function()
            -- Setup
            setup_test()
            ngx.shared.stats:set("192.168.1.1:rate", 101)

            -- Execute
            local result = rate_limit:handle()

            -- Verify
            test_utils.assert_false(result)
            test_utils.assert_equals(ngx.status, 429)
        end
    },
    {
        name = "Test: Error handling",
        func = function()
            -- Setup
            setup_test()
            ngx.shared.stats.get = function() error("Storage error") end

            -- Execute
            local result = rate_limit:handle()

            -- Verify
            test_utils.assert_false(result)
            test_utils.assert_equals(ngx.status, 500)
        end
    }
}

return _M
```

```

```

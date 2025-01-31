# Writing Tests

This guide explains how to write tests for the API Gateway using our Lua-based testing framework.

## Table of Contents

- [Writing Tests](#writing-tests)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Test Directory Structure](#test-directory-structure)
  - [Writing Test Files](#writing-test-files)
    - [Basic Test File Structure](#basic-test-file-structure)
    - [Example Test Case](#example-test-case)
  - [Test Structure](#test-structure)
  - [Lifecycle Hooks](#lifecycle-hooks)
  - [Assertions](#assertions)
  - [Mocking](#mocking)
  - [Debugging Tests](#debugging-tests)
  - [Best Practices](#best-practices)

## Overview

Our testing framework is built on top of OpenResty/Lua and provides a robust way to test API Gateway components. It supports:

- Unit tests and integration tests
- Request/response mocking
- Rich assertions
- Test lifecycle hooks
- Colored test output
- Detailed test reporting

## Test Directory Structure

Tests are organized under the `tests/` directory, mirroring the main project structure:

```
tests/
├── modules/      # Tests for core modules
├── services/     # Tests for service handlers
└── middleware/   # Tests for middleware components
```

Each test file should be named with a `_test.lua` suffix, matching the file it's testing. For example:

- `auth_middleware.lua` → `auth_middleware_test.lua`
- `health_service.lua` → `health_service_test.lua`

## Writing Test Files

### Basic Test File Structure

```lua
local test_runner = require "modules.test.test_runner"

-- Define the test module
local _M = {
    -- Optional lifecycle hooks
    before_all = function() end,
    after_all = function() end,
    before_each = function() end,
    after_each = function() end,

    -- Required test cases array
    tests = {
        {
            name = "test description",
            func = function()
                -- Test implementation
            end
        }
    }
}

return _M
```

### Example Test Case

```lua
local test_runner = require "modules.test.test_runner"

local _M = {
    tests = {
        {
            name = "should return 200 OK for valid request",
            func = function()
                -- Setup test data
                test_runner.mock.set_method("GET")
                test_runner.mock.set_uri("/health")

                -- Run the handler
                local response = require("services.health").handle()

                -- Assert the results
                test_runner.assert_equals(200, ngx.status, "Status should be 200")
                test_runner.assert_not_nil(response, "Response should not be nil")
            end
        }
    }
}

return _M
```

## Test Structure

Each test case should follow this structure:

1. **Setup**: Prepare the test environment and data
2. **Execute**: Run the code being tested
3. **Assert**: Verify the results
4. **Cleanup**: Clean up any resources (usually handled by `after_each`)

## Lifecycle Hooks

The framework provides four lifecycle hooks:

1. `before_all`: Runs once before all tests in the file
2. `before_each`: Runs before each test case
3. `after_each`: Runs after each test case
4. `after_all`: Runs once after all tests in the file

Example usage:

```lua
local _M = {
    before_all = function()
        -- Setup shared test resources
    end,

    before_each = function()
        -- Reset state before each test
        test_runner.reset_state()
    end,

    after_each = function()
        -- Clean up after each test
    end,

    after_all = function()
        -- Clean up shared resources
    end
}
```

## Assertions

The framework provides several assertion methods:

```lua
-- Basic assertions
test_runner.assert_equals(expected, actual, message)
test_runner.assert_not_equals(expected, actual, message)
test_runner.assert_nil(value, message)
test_runner.assert_not_nil(value, message)
test_runner.assert_true(value, message)
test_runner.assert_false(value, message)

-- Type assertions
test_runner.assert_type(value, expected_type, message)

-- Table assertions
test_runner.assert_table_equals(expected, actual, message)

-- String pattern matching
test_runner.assert_matches(value, pattern, message)
```

## Mocking

The framework provides comprehensive request mocking capabilities:

```lua
-- Mock request method
test_runner.mock.set_method("POST")

-- Mock URI
test_runner.mock.set_uri("/api/v1/resource")

-- Mock query parameters
test_runner.mock.set_uri_args({
    page = "1",
    limit = "10"
})

-- Mock request headers
test_runner.mock.set_headers({
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer token123"
})

-- Mock request body
test_runner.mock.set_body('{"key": "value"}')

-- Mock POST parameters
test_runner.mock.set_post_args({
    username = "john",
    password = "secret"
})
```

## Debugging Tests

When tests fail, you can:

1. Enable debug logging:

   ```lua
   ngx.log(ngx.DEBUG, "Debug information")
   ```

2. Inspect mock state:

   ```lua
   ngx.log(ngx.DEBUG, "Current mock state: " .. cjson.encode({
       status = ngx.status,
       headers = mock_headers,
       method = mock_method
   }))
   ```

3. Use the test runner's built-in state tracking:
   - Last exit code: `test_runner.last_exit_code`
   - Assertion counts: `ngx.ctx.test_successes`, `ngx.ctx.test_failures`

## Best Practices

1. **Test Organization**

   - Keep test files close to the code they're testing
   - Use descriptive test names that explain the behavior being tested
   - Group related tests together

2. **Test Independence**

   - Each test should be independent and not rely on other tests
   - Use `before_each` to reset state between tests
   - Don't share mutable state between tests

3. **Mocking**

   - Mock only what's necessary
   - Reset mocks between tests
   - Use meaningful test data

4. **Assertions**

   - Use specific assertions rather than generic ones
   - Write clear assertion messages
   - Test both positive and negative cases

5. **Error Handling**

   - Test error cases explicitly
   - Verify error messages and status codes
   - Test edge cases and boundary conditions

6. **Code Quality**

   - Keep test code as clean as production code
   - Don't duplicate test code - use helper functions
   - Comment complex test scenarios

7. **Performance**
   - Keep tests focused and efficient
   - Avoid unnecessary setup/teardown
   - Use appropriate test granularity


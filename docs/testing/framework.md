## Overview

The project implements a custom testing framework built on top of OpenResty/Lua, designed specifically for testing API Gateway functionality. The framework provides a robust set of testing utilities, mock capabilities, and assertion functions.

## Test Structure

### Test File Organization

- Test files should be named with the suffix `_test.lua`
- Tests can be organized in directories matching the structure of the code being tested
- Test files are automatically discovered based on the `_test.lua` suffix

### Basic Test File Structure

```lua
local _M = {
    -- Optional lifecycle hooks
    before_all = function() end,
    before_each = function() end,
    after_each = function() end,
    after_all = function() end,

    -- Required test array
    tests = {
        {
            name = "Test case description",
            func = function()
                -- Test implementation
            end
        },
        -- More test cases...
    }
}

return _M
```

## Running Tests

### HTTP Endpoint

Tests can be run via the HTTP endpoint at `/tests`:

- `GET /tests` - Runs all tests in the project
- `GET /tests/{path}` - Runs specific tests based on the path

### Test Path Examples

- `/tests` - Runs all tests
- `/tests/modules/core` - Runs all tests in the core modules directory
- `/tests/modules/core/router_test.lua` - Runs a specific test file

## Mock Capabilities

### Request Mocking

```lua
-- Set request method
_M.mock.set_method("POST")

-- Set request headers
_M.mock.set_headers({
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer token"
})

-- Set request body
_M.mock.set_body('{"key": "value"}')

-- Set URI args
_M.mock.set_uri_args({page = "1", limit = "10"})

-- Set POST args
_M.mock.set_post_args({username = "test", password = "pass"})
```

### NGX Context Mocking

The framework automatically mocks the following ngx variables and functions:

- `ngx.ctx`
- `ngx.shared`
- `ngx.status`
- `ngx.header`
- `ngx.exit`
- Request-related functions (`ngx.req.*`)

## Assertion Functions

### Basic Assertions

```lua
-- Equality assertions
_M.assert_equals(expected, actual, "message")
_M.assert_not_equals(expected, actual, "message")

-- Nil checks
_M.assert_nil(value, "message")
_M.assert_not_nil(value, "message")

-- Boolean assertions
_M.assert_true(value, "message")
_M.assert_false(value, "message")
```

### Type and Table Assertions

```lua
-- Type checking
_M.assert_type(value, "string", "message")

-- Table comparison
_M.assert_table_equals(expected_table, actual_table, "message")

-- String pattern matching
_M.assert_matches(string_value, pattern, "message")
```

## Example Test File

```lua
local test_runner = require "modules.test.test_runner"

local _M = {
    before_all = function()
        -- Setup code that runs once before all tests
    end,

    before_each = function()
        -- Setup code that runs before each test
        test_runner.mock.set_method("GET")
        test_runner.mock.set_headers({
            ["Content-Type"] = "application/json"
        })
    end,

    after_each = function()
        -- Cleanup code that runs after each test
    end,

    tests = {
        {
            name = "should handle GET request correctly",
            func = function()
                -- Test implementation
                local response = your_handler()
                test_runner.assert_equals(200, ngx.status, "Status should be 200")
                test_runner.assert_not_nil(response, "Response should not be nil")
                test_runner.assert_table_equals(
                    {success = true},
                    response,
                    "Response should match expected structure"
                )
            end
        },
        {
            name = "should handle error cases",
            func = function()
                test_runner.mock.set_headers({})  -- Clear headers
                local response = your_handler()
                test_runner.assert_equals(400, ngx.status, "Status should be 400")
            end
        }
    }
}

return _M
```

## Test Output

The framework provides colored output in the terminal:

- ✓ Green checkmark for passed tests
- ✗ Red X for failed tests
- Detailed error messages for failures
- Summary statistics including:
  - Total number of test files
  - Total tests run
  - Passed/Failed tests count
  - Total assertions
  - Passed/Failed assertions count

## Best Practices

1. **Test Organization**

   - Keep test files close to the code they're testing
   - Use descriptive test names
   - Group related tests together

2. **Mocking**

   - Reset mocks in `before_each` when needed
   - Use appropriate mock functions for the specific test case
   - Clean up mocks in `after_each` if necessary

3. **Assertions**

   - Use specific assertions rather than generic equality checks
   - Provide meaningful error messages
   - Test both success and failure cases

4. **Test Isolation**

   - Each test should be independent
   - Use `before_each` and `after_each` to ensure clean state
   - Don't rely on state from other tests

5. **Error Handling**
   - Test error conditions explicitly
   - Verify error messages and status codes
   - Test edge cases and boundary conditions

This testing framework provides a robust foundation for testing API Gateway functionality with comprehensive mocking capabilities and assertion functions. The HTTP endpoint makes it easy to run tests during development and in CI/CD pipelines.

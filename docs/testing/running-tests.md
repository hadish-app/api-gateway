# Running Tests

This document provides a comprehensive guide for running tests in the API Gateway project.

## Overview

The API Gateway includes a robust testing framework built on OpenResty/Lua that supports:

- Unit tests
- Integration tests
- HTTP endpoint testing
- Mock capabilities for ngx.\* functions
- Detailed test reporting

## Test Structure

Tests should be organized in the `tests` directory with the following naming convention:

- Test files must end with `_test.lua`
- Test files should mirror the structure of the source code they're testing

Example structure:

```
tests/
  ├── services/
  │   └── health_service_test.lua
  ├── modules/
  │   └── auth/
  │       └── jwt_test.lua
  └── integration/
      └── api_test.lua
```

## Writing Tests

Each test file should return a module with the following structure:

```lua
local _M = {
    -- Optional setup/teardown hooks
    before_all = function() end,
    after_all = function() end,
    before_each = function() end,
    after_each = function() end,

    -- Required test cases
    tests = {
        {
            name = "Test description",
            func = function()
                -- Test implementation
            end
        }
    }
}

return _M
```

## Running Tests

### HTTP Endpoint

Tests can be run through the HTTP endpoint:

```bash
# Run all tests
curl http://localhost:8080/tests

# Run specific test file or directory
curl http://localhost:8080/tests/services/health_service
curl http://localhost:8080/tests/modules/auth/jwt_test.lua
```

### Available Assertions

The test framework provides several assertion functions:

```lua
-- Core assertions
assert_equals(expected, actual, message)
assert_not_equals(expected, actual, message)
assert_not_nil(value, message)
assert_nil(value, message)
assert_true(value, message)
assert_false(value, message)

-- Type assertions
assert_type(value, expected_type, message)

-- Table assertions
assert_table_equals(expected, actual, message)

-- String pattern matching
assert_matches(value, pattern, message)
```

### Mocking Capabilities

The test framework provides comprehensive mocking for ngx.\* functions:

```lua
-- Example: Setting up request mocks
test_runner.mock.set_headers({["Content-Type"] = "application/json"})
test_runner.mock.set_method("POST")
test_runner.mock.set_uri("/api/v1/resource")
test_runner.mock.set_uri_args({page = "1"})
test_runner.mock.set_post_args({name = "test"})
test_runner.mock.set_body('{"key": "value"}')
```

## Test Results

The test runner provides detailed output including:

1. Individual test results with:

   - Test name
   - Pass/fail status
   - Error messages for failures
   - Assertion counts

2. Suite summary for each test file:

   - Total tests
   - Passed tests
   - Failed tests
   - Total assertions
   - Passed assertions
   - Failed assertions

3. Overall summary across all test files:
   - Total test files
   - Total tests
   - Total assertions
   - Pass/fail counts for both tests and assertions
   - List of failed test files with error messages

Example output:

```
=== Running tests from: tests/services/health_service_test.lua ===

Test: Should return 200 for healthy service
✓ Status code matches
✓ Response body is correct

Suite Summary for tests/services/health_service_test.lua:

Tests:
Total: 1
Passed: 1
Failed: 0

Assertions:
Total: 2
Passed: 2
Failed: 0

=== Overall Test Summary ===

Total Test Files: 1

Tests:
Total: 1
Passed: 1
Failed: 0

Assertions:
Total: 2
Passed: 2
Failed: 0
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
   - Use descriptive test names
   - Group related tests together

2. **Test Setup**

   - Use `before_all` for one-time setup
   - Use `before_each` for per-test setup
   - Clean up resources in `after_each` and `after_all`

3. **Assertions**

   - Use specific assertions when possible
   - Provide meaningful error messages
   - Test both positive and negative cases

4. **Mocking**

   - Reset mocks between tests
   - Only mock what's necessary
   - Verify mock interactions when relevant

5. **Error Handling**
   - Test error conditions
   - Verify error messages and status codes
   - Test edge cases and boundary conditions

## Contributing

When adding new tests:

1. Follow the existing test file structure
2. Add appropriate documentation
3. Ensure all tests are properly isolated
4. Verify both success and failure cases
5. Include relevant mock setup and teardown

# API Gateway Testing Guide

This directory contains the test suite for the API Gateway. The tests are organized by module and type to ensure maintainability and clarity.

## Directory Structure

```
/tests
  /modules           # Tests for core modules
    /core            # Core module tests
      config_init_test.lua
    /utils           # Utils module tests (env, log, etc.)  
      env_test.lua   # Test for env.lua
  /core             # Test utilities and helpers
    test_utils.lua   # Core test utilities
```

## Test Types

### Module Tests

Located in `/tests/modules/`, these tests verify the functionality of individual modules. Each test file corresponds to a module or a module function in the main codebase.

Example:

- `/modules/core/config.lua` → `/tests/modules/core/config_test.lua`
- `/modules/core/config.lua` init() → `/tests/modules/core/config_init_test.lua`

## Running Tests

### Module Tests

To run tests for a specific module, use the following endpoint pattern:

```
GET /test/modules/core/{test_name}
```

Example:

```bash
# Test the config module
curl http://localhost:8080/test/modules/core/config_test
```

## Test Utilities

### test_utils.lua

Provides core testing functionality:

- Test suite execution
- Assertion functions
- Test result reporting

## Writing Tests

### File Naming Convention

- Use `_test.lua` suffix for all test files
- Match the module structure in the test directory
- Example: `config_test.lua` for testing `config.lua`
- Example: `config_init_test.lua` for testing the init() function of `config.lua`

### Test Structure

```lua
local test_utils = require "tests.core.test_utils"

local _M = {}

_M.tests = {
    {
        name = "Test case description",
        func = function()
            -- Test implementation
            test_utils.assert_equals(expected, actual, "Assert message")
        end
    }
}

return _M
```

### Best Practices

1. Each test should focus on a single functionality
2. Use descriptive test names
3. Include both positive and negative test cases
4. Clean up any test data or state after tests
5. Keep tests independent of each other

## Test Configuration

Test endpoints are configured in `configs/locations/test.conf`. The configuration uses nginx location blocks to map test URLs to the appropriate test files.

# Testing Documentation

## Overview

The API Gateway implements a comprehensive testing framework built on Lua and integrated with nginx. This document outlines the testing architecture, methodologies, and best practices for maintaining and extending the test suite.

## Table of Contents

1. [Testing Architecture](#testing-architecture)
2. [Directory Structure](#directory-structure)
3. [Test Types](#test-types)
4. [Writing Tests](#writing-tests)
5. [Running Tests](#running-tests)
6. [Test Utilities](#test-utilities)
7. [Best Practices](#best-practices)
8. [Continuous Integration](#continuous-integration)

## Testing Architecture

The testing framework is built on these core principles:

- Modular test organization
- HTTP-accessible test endpoints
- Automated test execution
- Detailed reporting and logging
- Independent test isolation

### Core Components

1. **Test Runner**: Built-in HTTP endpoints for test execution
2. **Assertion Framework**: Comprehensive assertion utilities
3. **Reporting System**: Colored output with detailed failure information
4. **Suite Management**: Test grouping and batch execution

## Directory Structure

```
/tests
├── README.md                 # Testing overview and quick start
├── core/                     # Core testing framework
│   └── test_utils.lua       # Testing utilities and assertions
├── modules/                  # Module-specific tests
│   ├── core/                # Core module tests
│   │   └── config_init_test.lua
│   └── utils/               # Utility module tests
│       └── env_test.lua
```

## Test Types

### 1. Module Tests

- Test individual module functionality
- Located in `/tests/modules/{module_name}/`
- One test file per module or major function
- Naming convention: `{module_name}_test.lua`

### 2. Integration Tests

- Test interaction between modules
- Verify end-to-end workflows
- Located in module-specific directories
- Focus on API contracts and interfaces

## Writing Tests

### Test File Structure

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

### Assertion Functions

```lua
-- Basic equality assertion
test_utils.assert_equals(expected, actual, "Assert message")

-- Example usage
test_utils.assert_equals(200, response.status, "Should return 200 OK")
```

## Running Tests

### Via HTTP Endpoints

```bash
# Run specific module test
curl http://localhost:8080/test/modules/core/config_test

# Run all tests in a module
curl http://localhost:8080/test/modules/core
```

### Test Output

```
Running config_test tests...

Test initialization with valid config
✓ Config loaded successfully
✓ Required fields present

Test initialization with invalid config
✓ Error handled properly

Results: 3 passed, 0 failed
```

## Test Utilities

The `test_utils.lua` module provides core testing functionality:

### Key Features

1. **Assertion Functions**

   - Equality checking
   - Type validation
   - Error handling

2. **Suite Management**

   - Test grouping
   - Setup and teardown
   - Result aggregation

3. **Reporting**
   - Colored output
   - Detailed error messages
   - Statistics summary

## Best Practices

1. **Test Organization**

   - One test file per module/function
   - Clear, descriptive test names
   - Logical test grouping

2. **Test Independence**

   - Each test should be self-contained
   - Clean up after each test
   - No dependencies between tests

3. **Test Coverage**

   - Test both success and failure cases
   - Include edge cases
   - Test configuration variations

4. **Code Quality**

   - Keep tests simple and focused
   - Use descriptive variable names
   - Comment complex test logic

5. **Maintenance**
   - Update tests when modifying code
   - Remove obsolete tests
   - Keep documentation current

## Continuous Integration

### Test Execution

Tests are automatically run:

1. On every commit
2. During deployment
3. In nightly builds

### Test Requirements

- All tests must pass before deployment
- New features require test coverage
- Failed tests block merges

### Monitoring

- Test results are logged
- Failures trigger notifications
- Coverage reports generated

## Extending the Framework

### Adding New Test Types

1. Create new test directory
2. Implement test utilities if needed
3. Update documentation
4. Add CI configuration

### Custom Assertions

```lua
-- Example custom assertion
function test_utils.assert_response_valid(response)
    test_utils.assert_equals(200, response.status)
    test_utils.assert_equals("application/json", response.headers["Content-Type"])
end
```

## Troubleshooting

### Common Issues

1. **Failed Tests**

   - Check test dependencies
   - Verify test environment
   - Review recent changes

2. **Slow Tests**
   - Optimize test setup
   - Run tests in parallel
   - Profile test execution

### Getting Help

- Review test logs
- Check documentation
- Contact development team

# Startup Flow Testing Plan

## Overview

This document outlines the test plan for the API Gateway startup flow, covering the initialization sequence from nginx startup through worker process initialization.

## Test Categories

### 1. Master Process Initialization Tests

#### 1.1 Core Module Loading

**Module**: `init.lua`
**Function**: `bootstrap()`

```lua
-- Test cases needed:
- Verify core modules are loaded (config, error_handler, init)
- Test loading of resty.core and resty.jit-uuid
- Verify error handling for missing core libraries
```

#### 1.2 Shared Dictionary Verification

**Module**: `init.lua`
**Function**: `verify_shared_dicts()`

```lua
-- Test cases needed:
- Verify all required dictionaries are present
- Test error handling for missing dictionaries
- Verify dictionary initialization states
- Test dictionary access permissions
```

#### 1.3 UUID Library Initialization

**Module**: `init.lua`
**Function**: `bootstrap()`

```lua
-- Test cases needed:
- Verify UUID library initialization
- Test UUID generation functionality
- Verify seed initialization
```

### 2. Configuration System Tests

#### 2.1 Configuration Loading

**Module**: `core/config.lua`
**Function**: `init()`

```lua
-- Test cases needed:
- Test loading from environment variables
- Verify type conversions (using type_conversion.lua)
- Test configuration caching
- Verify section organization
- Test error handling for invalid configurations
```

#### 2.2 Configuration Access

**Module**: `core/config.lua`
**Functions**: `get()`, `get_section()`

```lua
-- Test cases needed:
- Test retrieval of individual values
- Test retrieval of entire sections
- Verify type consistency
- Test access to non-existent values
- Test concurrent access from multiple workers
```

### 3. Shared State Tests

#### 3.1 State Initialization

**Module**: `init.lua`
**Function**: `init_shared_states()`

```lua
-- Test cases needed:
- Verify initial state values
- Test state accessibility
- Verify atomic operations
- Test concurrent modifications
- Verify state persistence across worker reloads
```

#### 3.2 Metrics Initialization

**Module**: `init.lua`
**Function**: `init_shared_states()`

```lua
-- Test cases needed:
- Verify metrics initialization
- Test metrics update operations
- Verify metrics accuracy
- Test concurrent metrics updates
```

### 4. Worker Process Tests

#### 4.1 Worker Initialization

**Module**: `init.lua`
**Function**: `start_worker()`

```lua
-- Test cases needed:
- Verify worker startup sequence
- Test worker-specific state initialization
- Verify worker event handling
- Test worker communication
```

#### 4.2 Cleanup Timer

**Module**: `init.lua`
**Function**: `start_worker()`

```lua
-- Test cases needed:
- Verify timer creation
- Test cleanup execution
- Verify expired entry removal
- Test timer persistence
- Verify cleanup across all dictionaries
```

## Test Implementation Priority

1. **Critical Path** (Implement First):

   - Core module loading
   - Shared dictionary verification
   - Basic configuration loading
   - Worker initialization

2. **Essential Features** (Implement Second):

   - Configuration type conversion
   - Shared state initialization
   - Metrics initialization
   - Cleanup timer functionality

3. **Edge Cases** (Implement Third):
   - Error handling
   - Concurrent access
   - Resource cleanup
   - Recovery scenarios

## Test File Structure

```
/tests
├── modules/
│   ├── core/
│   │   ├── init_test.lua           # Core initialization tests
│   │   ├── init_bootstrap_test.lua # Bootstrap process tests
│   │   ├── init_worker_test.lua    # Worker initialization tests
│   │   └── config_test.lua         # Configuration tests
│   └── integration/
│       ├── startup_flow_test.lua   # End-to-end startup tests
│       └── worker_flow_test.lua    # Worker lifecycle tests
```

## Test Implementation Guidelines

1. **Isolation**:

   - Each test should run in isolation
   - Clean up shared states between tests
   - Mock external dependencies

2. **Coverage**:

   - Test both success and failure paths
   - Include edge cases
   - Test concurrent scenarios

3. **Verification**:

   - Verify state changes
   - Check error conditions
   - Validate cleanup operations

4. **Documentation**:
   - Document test prerequisites
   - Explain test scenarios
   - Include example outputs

## Example Test Implementation

```lua
-- Example test structure for init_test.lua
local test_utils = require "tests.core.test_utils"
local init = require "core.init"

local _M = {}

_M.tests = {
    {
        name = "Test core module loading",
        func = function()
            -- Test implementation
        end
    },
    {
        name = "Test shared dictionary verification",
        func = function()
            -- Test implementation
        end
    }
    -- Additional tests...
}

return _M
```

## Next Steps

1. Implement critical path tests
2. Set up test environment
3. Create mock objects for dependencies
4. Implement test utilities for startup testing
5. Add integration tests
6. Document test results and coverage

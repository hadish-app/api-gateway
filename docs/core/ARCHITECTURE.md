# Core Architecture

## Overview

The API Gateway implements a hybrid architecture that combines OpenResty's phase-based processing with a flexible middleware system. This document explains the core architecture, design decisions, and how to extend the system.

## Core Components

### 1. Phase Handler System (`modules/core/phase_handlers.lua`)

The phase handler manages the OpenResty request lifecycle and coordinates middleware execution:

```lua
-- Initialization Phases
init()              -- Server initialization
init_worker()       -- Worker process initialization

-- Request Processing Phases
access()           -- Authentication and authorization
content()          -- Main request processing
header_filter()    -- Response header modification
body_filter()      -- Response body modification
log()             -- Logging and cleanup
```

**Key Features**:

- Shared dictionary management
- Worker initialization
- Phase-specific middleware execution
- Error handling and recovery

### 2. Middleware Chain (`modules/core/middleware_chain.lua`)

Manages middleware registration, ordering, and execution:

```lua
-- Middleware Storage
local global_middleware = {}  -- For all routes
local route_middleware = {}   -- Per-route middleware

-- States
local STATES = {
    ACTIVE = "active",
    DISABLED = "disabled"
}
```

**Key Features**:

- Priority-based execution
- Route-specific middleware
- State management (active/disabled)
- Error handling with chain interruption

### 3. Middleware Registry (`modules/core/middleware_registry.lua`)

Centralizes middleware registration and configuration:

```lua
-- Valid Processing Phases
local PHASES = {
    access = true,
    content = true,
    header_filter = true,
    body_filter = true,
    log = true
}

-- Middleware Registry
local REGISTRY = {
    request_id = {
        module = "modules.middleware.request_id",
        state = "active",
        multi_phase = true,
        phases = {
            access = { priority = 10 },
            header_filter = { priority = 10 },
            log = { priority = 10 }
        }
    }
}
```

**Key Features**:

- Centralized configuration
- Multi-phase middleware support
- Priority management
- Validation and error handling

## Request Flow

1. **Initialization**:

   ```lua
   -- In nginx.conf
   init_by_lua_block {
       require("core.phase_handlers").init()
   }

   init_worker_by_lua_block {
       require("core.phase_handlers").init_worker()
   }
   ```

2. **Request Processing**:

   ```lua
   -- For each phase
   phase_handlers.access()       -- Authentication, rate limiting
   phase_handlers.content()      -- Request handling
   phase_handlers.header_filter() -- Response headers
   phase_handlers.body_filter()  -- Response body
   phase_handlers.log()         -- Logging, metrics
   ```

3. **Middleware Execution**:
   ```lua
   -- In each phase
   local chain = middleware_chain.get_chain(uri, phase)
   for _, middleware in ipairs(chain) do
       if middleware.state == STATES.ACTIVE then
           local ok, result = middleware:handle()
           if not ok or result == false then
               -- Handle error or chain interruption
           end
       end
   end
   ```

## State Management

### 1. Request Context (`ngx.ctx`)

For request-scoped data:

```lua
-- Store request-specific data
ngx.ctx.request_id = uuid.generate()
ngx.ctx.start_time = ngx.now()

-- Access in any phase
local request_id = ngx.ctx.request_id
```

### 2. Shared Dictionaries

For worker-level shared state:

```lua
-- In nginx.conf
lua_shared_dict stats 10m;
lua_shared_dict config_cache 5m;

-- In middleware
local stats = ngx.shared.stats
stats:set("total_requests", stats:get("total_requests") + 1)
```

### 3. Configuration Management

For dynamic configuration:

```lua
-- In middleware_registry.lua
local REGISTRY = {
    multi_phase_example = {
        module = "modules.middleware.multi_phase_example",
        state = "active",
        multi_phase = true,
        phases = {
            access = { priority = 10 },
            header_filter = { priority = 20 }
        }
    }
}
```

### 3. Adding New Features

1. **Add Shared Dictionary**:

   ```lua
   -- 1. Declare in nginx.conf
   lua_shared_dict new_feature 10m;

   -- 2. Add to SHARED_DICTS in phase_handlers.lua
   local SHARED_DICTS = {
       required = {
           "new_feature",  -- New shared dictionary
           -- ... existing dictionaries
       }
   }
   ```

2. **Add New Phase Handler**:
   ```lua
   -- In phase_handlers.lua
   function _M.new_phase()
       local result = middleware_chain.run_chain("new_phase")
       return result
   end
   ```

## Testing

### 1. Middleware Testing

```lua
-- tests/modules/middleware/example_test.lua
local _M = {}

_M.tests = {
    {
        name = "Test: Basic functionality",
        func = function()
            -- Setup
            test_utils.reset_state()

            -- Execute
            local result = middleware:handle()

            -- Verify
            test_utils.assert_true(result)
        end
    }
}
```

### 2. Integration Testing

```lua
-- Use test endpoints
curl http://localhost:8080/tests/modules/middleware/example_test
```

## Best Practices

1. **Middleware Development**:

   - Use appropriate phases for operations
   - Implement proper error handling
   - Follow naming conventions
   - Document configuration options

2. **State Management**:

   - Use `ngx.ctx` for request scope
   - Use shared dictionaries for worker scope
   - Implement proper cleanup
   - Handle concurrent access

3. **Error Handling**:

   - Use pcall for risky operations
   - Log errors with context
   - Implement graceful degradation
   - Provide meaningful error messages

4. **Performance**:
   - Minimize shared dictionary access
   - Use appropriate cache strategies
   - Monitor memory usage
   - Implement proper timeouts

## Future Development

1. **Planned Features**:

   - Dynamic middleware loading
   - Enhanced monitoring and metrics
   - Advanced routing patterns
   - Caching improvements

2. **Enhancement Areas**:

   - Configuration management
   - Security features
   - Performance optimization
   - Testing infrastructure

3. **Contributing Guidelines**:
   - Follow existing patterns
   - Add comprehensive tests
   - Update documentation
   - Consider backward compatibility

```

```

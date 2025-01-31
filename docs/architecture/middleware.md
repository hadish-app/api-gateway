# Middleware System

The middleware system provides a sophisticated request/response processing pipeline with multi-phase support, priority-based execution, and comprehensive error handling.

## Overview

The middleware system is designed to be:

- Flexible and extensible
- Phase-aware
- Priority-based
- Error-resilient
- Configuration-driven

## Core Concepts

### Middleware Types

#### 1. Global Middleware

Applies to all routes and can be either single-phase or multi-phase:

```lua
-- Example of multi-phase global middleware
request_id = {
    module = "middleware.request_id",
    enabled = true,
    multi_phase = true,
    phases = {
        access = { priority = 10 },
        header_filter = { priority = 10 },
        log = { priority = 10 }
    }
}

-- Example of single-phase global middleware
router = {
    module = "middleware.router",
    enabled = true,
    phase = "content",
    priority = 100
}
```

#### 2. Route-Specific Middleware

Applies only to specified paths:

```lua
cors = {
    module = "middleware.cors.cors_main",
    enabled = true,
    multi_phase = true,
    phases = {
        access = { priority = 20 },
        header_filter = { priority = 20 }
    },
    routes = {
        ["/api/v1/health"] = {
            allow_origins = {"http://specific-origin.com"},
            allow_methods = {"GET", "OPTIONS"}
        }
    }
}
```

### Phase-Based Execution

#### 1. NGINX Phases

The middleware system operates across different NGINX request processing phases:

| Phase           | Purpose                      |
| --------------- | ---------------------------- |
| `access`        | Authentication/authorization |
| `content`       | Main request processing      |
| `header_filter` | Response header modification |
| `body_filter`   | Response body modification   |
| `log`           | Logging and cleanup          |

#### 2. Phase Configuration

Each middleware can specify:

- Which phases it operates in
- Priority for each phase
- Phase-specific behavior
- State management across phases

### Priority System

#### 1. Priority Assignment

The middleware system uses a simple numeric priority system where:

- Priority is specified as a number when registering middleware
- Lower numbers execute first (e.g., 10 executes before 50)
- If priority is not specified, it will be assigned by the middleware registry
- The same priority system applies to both global and route-specific middleware

```lua
-- Example middleware with priority
local middleware = {
    name = "my_middleware",
    priority = 10,  -- Will execute early in the chain
    phase = "content",
    handle = function(self)
        -- Implementation
    end
}
```

#### 2. Execution Order

- Middleware is sorted by priority (lower numbers run first)
- Middleware with the same priority executes in registration order
- Priority sorting is applied separately to:
  - Global middleware chain
  - Each route-specific middleware chain
- Priority is phase-independent (same priority applies across all phases)

## Implementation Details

### Error Handling

#### 1. Middleware Termination

```lua
function middleware:handle()
    if error_condition then
        return false  -- Terminate this middleware
    end
    return true  -- Continue execution
end
```

#### 2. Error Recovery

```lua
-- Protected execution with error handling
local ok, result = pcall(function()
    return middleware:handle()
end)
if not ok then
    ngx.log(ngx.ERR, "Middleware error: ", result)
    return false
end
```

### State Management

#### 1. Shared State

```lua
-- Using shared dictionaries
local shared_dict = ngx.shared.my_cache
shared_dict:set("key", "value", 60)  -- 60s TTL
```

#### 2. Request Context

```lua
-- Using ngx.ctx for request-scoped data
ngx.ctx.my_data = "value"
```

## Core Middleware Components

### 1. Router Middleware

**Purpose**: Handles core routing functionality

**Features**:

- Path-based routing
- Method handling
- Parameter extraction
- Route matching

### 2. CORS Middleware

**Purpose**: Manages Cross-Origin Resource Sharing

**Features**:

- Origin validation
- Method validation
- Header management
- Preflight handling

### 3. Request ID Middleware

**Purpose**: Provides request tracing and correlation

**Features**:

- UUID generation
- Header injection
- Correlation tracking

## Development Guide

### Creating New Middleware

#### 1. Basic Structure

```lua
local middleware = {
    name = "my_middleware",
    priority = 50,
    phase = "content",

    handle = function(self)
        -- Implementation
        return true
    end
}
```

#### 2. Multi-Phase Structure

```lua
local middleware = {
    name = "my_middleware",
    multi_phase = true,
    phases = {
        access = {
            priority = 20,
            handle = function(self)
                -- Access phase logic
                return true
            end
        },
        content = {
            priority = 50,
            handle = function(self)
                -- Content phase logic
                return true
            end
        }
    }
}
```

### Best Practices

#### 1. Performance

- Minimize shared state access
- Use local caching when possible
- Early termination for invalid requests
- Efficient error handling

#### 2. Error Handling

- Always use pcall for protected execution
- Proper error logging
- Graceful degradation
- Clean state management

#### 3. State Management

- Clear state initialization
- Proper cleanup in log phase
- Request-scoped data in ngx.ctx
- Careful shared dictionary usage

#### 4. Configuration

- Clear configuration structure
- Validation of settings
- Sensible defaults
- Documentation of options

## Integration Points

### System Architecture

#### 1. Component Separation

- Clear separation of concerns
- Modular architecture
- Independent component lifecycle

#### 2. Interface Standardization

- Consistent middleware interface
- Standardized error handling
- Uniform configuration patterns

#### 3. Architecture Benefits

- Extensible design
- Performance optimization opportunities
- Security implementation framework
- Comprehensive logging system

### Component Guidelines

Each middleware component follows:

- Single responsibility principle
- Clear interface definition
- Consistent error handling patterns
- Comprehensive logging practices
- Flexible configuration options

## Next Steps

- Learn about [Core Components](core-components.md)
- Explore [Services](services.md)
- Read the [Configuration Guide](../configuration/overview.md)

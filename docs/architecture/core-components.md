# Core Components

The core components form the foundation of the API Gateway, providing essential functionality through a well-structured, modular architecture. These components work together to handle request processing, routing, service management, and configuration across the system.

## Component Overview

The core components are organized into several key areas:

1. **Phase Handlers**: Manage the NGINX request lifecycle
2. **Route Registry**: Handle dynamic route registration and matching
3. **Service Registry**: Manage service lifecycle and configuration
4. **Specification Loader**: Process OpenAPI specifications
5. **Middleware Registry**: Handle middleware registration and execution
6. **Configuration Cache**: Manage runtime configurations

Each component is designed to be modular, maintainable, and performant, following the API Gateway's architectural principles.

## Phase Handlers

The Phase Handlers module (`phase_handlers.lua`) manages the NGINX request processing lifecycle, ensuring proper execution of middleware and request handling across different phases.

### Key Phases

```lua
-- Example phase handler structure
local _M = {}

function _M.init()
    -- System initialization
    local ok, err = pcall(function()
        -- Initialize shared dictionaries
        init_shared_dicts()
        -- Load configurations
        load_configurations()
    end)
    if not ok then
        ngx.log(ngx.ERR, "Initialization failed: ", err)
        return false
    end
end

function _M.init_worker()
    -- Worker process initialization
    -- Start background tasks
    -- Initialize worker-specific resources
end

function _M.access()
    -- Authentication and authorization
    -- CORS validation
    -- Rate limiting checks
end

function _M.content()
    -- Main request processing
    -- Route matching and handling
    -- Service execution
end

function _M.header_filter()
    -- Response header modification
    -- Security headers
    -- CORS headers
end

function _M.body_filter()
    -- Response body modification
    -- Compression
    -- Content transformation
end

function _M.log()
    -- Logging and cleanup
    -- Metrics collection
    -- Error reporting
end
```

### State Management

Shared dictionaries for various purposes:

- `stats`: Runtime statistics
- `metrics`: Performance metrics
- `config_cache`: Configuration caching
- `rate_limit`: Rate limiting data
- `ip_blacklist`: IP blocking list
- `worker_events`: Worker communication

## Route Registry

The Route Registry module (`route_registry.lua`) handles dynamic route registration and lookup.

### Key Features

1. **Route Registration**

```lua
function _M.register(service_name, service_id, route_id, path, method, cors, route_handler)
    -- Validate parameters
    -- Register route handler
    -- Configure CORS settings
end
```

2. **Route Matching**

```lua
function _M.match(uri, method)
    -- Exact path matching
    -- Pattern matching
    -- Parameter extraction
    -- Handler lookup
end
```

3. **Route Management**

- Dynamic route addition/removal
- Pattern-based routing
- Method-specific handlers
- CORS configuration per route

## Service Registry

The Service Registry module (`service_registry.lua`) manages service registration and lifecycle.

### Functionality

1. **Service Registration**

```lua
local function register_service(name, config)
    -- Load service module
    -- Register routes
    -- Configure service settings
end
```

2. **Service Management**

- Service discovery
- Configuration management
- Route registration
- Error handling

## Specification Loader

The Specification Loader module (`spec_loader.lua`) processes OpenAPI specifications.

### Features

1. **Specification Processing**

```lua
function _M.load_spec(spec_path)
    -- Parse OpenAPI spec
    -- Extract route information
    -- Process CORS settings
    -- Configure service
end
```

2. **Configuration Generation**

- Route configuration
- CORS settings
- Service metadata
- Validation rules

## Middleware Registry

The Middleware Registry module (`middleware_registry.lua`) manages middleware registration and configuration.

### Core Features

1. **Middleware Registration**

```lua
function _M.register(name, config)
    -- Validate configuration
    -- Register phases
    -- Set priorities
    -- Configure middleware
end
```

2. **Phase Management**

```lua
local PHASES = {
    access = true,
    content = true,
    header_filter = true,
    body_filter = true,
    log = true
}
```

## Configuration Cache

The Configuration Cache module manages environment and runtime configurations.

### Implementation

1. **Cache Management**

```lua
local config_cache = ngx.shared.config_cache

-- Store configuration
function store_config(section, data)
    config_cache:set(section, cjson.encode(data))
end

-- Retrieve configuration
function get_config(section)
    return cjson.decode(config_cache:get(section))
end
```

2. **Features**

- Fast access to configurations
- Shared across worker processes
- Automatic type conversion
- Cache invalidation support

## Best Practices

### 1. Error Handling

```lua
-- Consistent error handling pattern
local function safe_operation(operation, error_context)
    local ok, result = pcall(operation)
    if not ok then
        -- Log with context
        ngx.log(ngx.ERR, "Operation failed: ", result, " Context: ", error_context)
        -- Return structured error
        return nil, {
            code = "OPERATION_FAILED",
            message = "Operation failure",
            details = result
        }
    end
    return result
end

-- Usage example
local function process_request()
    local result, err = safe_operation(
        function()
            -- Operation logic
        end,
        "Request processing"
    )
    if err then
        return handle_error(err)
    end
    return result
end
```

### 2. State Management

- Use shared dictionaries for shared state:

  ```lua
  local shared_dict = ngx.shared.stats
  shared_dict:set("requests", shared_dict:get("requests") + 1)
  ```

- Local variables for module state:

  ```lua
  local module_state = {
      initialized = false,
      config = {}
  }
  ```

- Context variables for request state:
  ```lua
  ngx.ctx.request_id = generate_uuid()
  ngx.ctx.start_time = ngx.now()
  ```

### 3. Performance Optimization

- Minimize shared dictionary access:

  ```lua
  -- Cache frequently accessed values
  local cached_value = shared_dict:get("key")
  ```

- Use local references:

  ```lua
  local ngx_log = ngx.log
  local ngx_ERR = ngx.ERR
  ```

- Optimize loops and conditions:

  ```lua
  -- Pre-compile patterns
  local PATTERN = ngx.re.compile([[^/api/v1/]])
  ```

- Cache frequently used values:
  ```lua
  local config_cache = {
      timeout = 60,
      max_retries = 3
  }
  ```

### 4. Code Organization

- Clear module interfaces:

  ```lua
  local _M = {
      version = "1.0.0",
      name = "module_name"
  }
  ```

- Consistent error handling:

  ```lua
  local function handle_error(err)
      return {
          success = false,
          error = err.message,
          code = err.code
      }
  end
  ```

- Comprehensive logging:

  ```lua
  local function log_operation(operation, context)
      ngx.log(ngx.INFO, "Operation: ", operation, " Context: ", context)
  end
  ```

- Proper initialization:
  ```lua
  function _M.init()
      -- Validate requirements
      -- Initialize resources
      -- Set up error handlers
  end
  ```

### 5. Security Considerations

- Input validation:

  ```lua
  local function validate_input(input)
      if not input or type(input) ~= "string" then
          return nil, "Invalid input"
      end
      return input
  end
  ```

- Secure configuration handling:

  ```lua
  local function get_secure_config()
      local config = ngx.shared.config_cache:get("secure_config")
      return config and cjson.decode(config) or {}
  end
  ```

- Error masking:
  ```lua
  local function mask_error(err)
      return {
          message = "An error occurred",
          code = "INTERNAL_ERROR",
          trace_id = ngx.ctx.request_id
      }
  end
  ```

## Integration Points

### 1. Component Communication

```lua
-- Example of component interaction
local function process_request()
    -- Route matching
    local route = route_registry.match(ngx.var.uri)

    -- Service lookup
    local service = service_registry.get_service(route.service_id)

    -- Middleware execution
    local ok = middleware_registry.execute_chain(route)

    -- Response handling
    return ok and service:handle(route) or error_response()
end
```

## Next Steps

- Learn about the [Middleware System](middleware.md)
- Explore [Services](services.md)
- Read about [Configuration](../configuration/overview.md)
- Review the [Development Guide](../development/getting-started.md)

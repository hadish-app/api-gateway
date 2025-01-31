# Services

Services in the API Gateway are self-contained modules that implement specific API endpoints, defined through OpenAPI specifications and implemented with Lua handlers.

## Service Structure

### Basic Layout

```plaintext
services/
└── service_name/
    ├── spec.yaml      # OpenAPI specification
    └── handler.lua    # Implementation
```

### OpenAPI Specification

```yaml
# Example from health_service/spec.yaml
openapi: 3.0.0
info:
  title: Service API
  version: 1.0.0
  description: Service description

x-service-info:
  id: service_id
  module: services.service_name.handler
  cors:
    allow_protocols: [http, https]
    allow_headers: [content-type, user-agent]
    allow_credentials: false
    max_age: 3600

paths:
  /endpoint:
    get:
      operationId: operationId
      x-route-info:
        id: route_id
        handler: handler_function
      cors:
        allow_origins: [origin.com]
        allow_methods: [GET]
```

### Handler Implementation

```lua
-- Example from health_service/handler.lua
local _M = {}

-- Private helper functions
local function helper_function()
    -- Implementation
end

-- Public endpoint handlers
function _M.handler_function()
    -- Implementation
    local data, err = helper_function()
    if err then
        return nil, err
    end

    -- Return response
    ngx.say(cjson.encode(data))
    return true
end

return _M
```

## Developing a New Service

### 1. Service Specification Template

```yaml
# services/new_service/spec.yaml
openapi: 3.0.0
info:
  title: New Service API
  version: 1.0.0
  description: Service description

x-service-info:
  id: new_service
  module: services.new_service.handler
  cors:
    allow_protocols: [http, https]
    allow_headers: [content-type]
    allow_credentials: false
    max_age: 3600

paths:
  /new-endpoint:
    get:
      operationId: newOperation
      x-route-info:
        id: operation_id
        handler: handle_operation
      cors:
        allow_origins: [allowed-origin.com]
        allow_methods: [GET]
```

### 2. Handler Template

```lua
-- services/new_service/handler.lua
local cjson = require "cjson"
local ngx = ngx

local _M = {}

-- Private helper functions
local function validate_input(input)
    -- Validation logic
    return true, nil
end

local function process_data(data)
    -- Processing logic
    return result, nil
end

-- Public endpoint handlers
function _M.handle_operation()
    -- Get request data
    local data = ngx.req.get_body_data()

    -- Validate input
    local ok, err = validate_input(data)
    if not ok then
        ngx.status = 400
        ngx.say(cjson.encode({
            error = "Invalid input",
            message = err
        }))
        return false
    end

    -- Process request
    local result, err = process_data(data)
    if err then
        ngx.status = 500
        ngx.say(cjson.encode({
            error = "Processing error",
            message = err
        }))
        return false
    end

    -- Return response
    ngx.say(cjson.encode(result))
    return true
end

return _M
```

## Best Practices

### 1. Error Handling

```lua
-- Consistent error handling pattern
local function handle_error(err)
    ngx.status = err.status or 500
    ngx.say(cjson.encode({
        error = err.type or "internal_error",
        message = err.message or "Internal server error"
    }))
    return false
end

-- Usage in handlers
function _M.handler()
    local result, err = operation()
    if err then
        return handle_error(err)
    end
end
```

### 2. Input Validation

```lua
local function validate_request()
    -- Method validation
    if ngx.req.get_method() ~= "POST" then
        return nil, {
            status = 405,
            type = "method_not_allowed",
            message = "Method not allowed"
        }
    end

    -- Body validation
    local body = ngx.req.get_body_data()
    if not body then
        return nil, {
            status = 400,
            type = "invalid_request",
            message = "Missing request body"
        }
    end

    return body
end
```

### 3. Response Formatting

```lua
local function send_response(data, status)
    ngx.status = status or 200
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode(data))
end
```

### 4. Caching

```lua
-- Cache frequently used data
local cache = ngx.shared.my_cache

local function get_cached_data(key)
    local data = cache:get(key)
    if not data then
        data = expensive_operation()
        cache:set(key, data, 60)  -- Cache for 60 seconds
    end
    return data
end
```

## Service Guidelines

1. **Service Design**

   - Single responsibility principle
   - Clear API contracts
   - Proper error handling
   - Input validation
   - Response formatting

2. **Performance**

   - Efficient data processing
   - Proper caching
   - Resource optimization
   - Error recovery

3. **Security**

   - Input sanitization
   - Access control
   - Rate limiting
   - Error masking

4. **Documentation**
   - Clear API specifications
   - Error documentation
   - Example requests/responses
   - Configuration options

## Health Service Example

The Health Service provides system health monitoring capabilities. Located in `/services/health_service/`, it demonstrates key service implementation features:

### Implementation Features

- OpenAPI 3.0 specification
- Service-level CORS configuration
- Multiple endpoints with different configurations

### Service Structure

- `spec.yaml`: OpenAPI definition
- `handler.lua`: Endpoint implementations
- Service-specific configurations
- Custom middleware settings

### Endpoints

```yaml
/health:
  - Basic health check
  - GET/OPTIONS methods
  - Custom CORS settings

/health/details:
  - Detailed health information
  - Extended response schema
  - Endpoint-specific CORS
```

### Example Implementation

```lua
-- services/health_service/handler.lua
local _M = {}

function _M.check()
    local health = {
        status = "healthy",
        timestamp = ngx.time(),
        version = "1.0.0",
        components = {
            database = check_database(),
            cache = check_cache(),
            services = check_services()
        }
    }

    ngx.say(cjson.encode(health))
    return true
end

return _M
```

## Next Steps

- Learn about [Configuration](../configuration/overview.md)
- Explore [Testing](../testing/framework.md)
- Read the [Development Guide](../development/getting-started.md)

# Service Configuration

Services in the API Gateway are configured through OpenAPI specifications and environment variables, providing a flexible and standardized way to define API endpoints.

## Service Definition

### 1. OpenAPI Specification

```yaml
# services/example_service/spec.yaml
openapi: 3.0.0
info:
  title: Example Service
  version: 1.0.0
  description: Example service description

x-service-info:
  id: example_service
  module: services.example_service.handler
  enabled: true
  cors:
    allow_protocols: [http, https]
    allow_headers: [content-type, authorization]
    allow_credentials: false
    max_age: 3600

paths:
  /api/v1/example:
    get:
      operationId: getExample
      x-route-info:
        id: get_example
        handler: handle_get
      cors:
        allow_origins: [origin.com]
        allow_methods: [GET]
```

### 2. Service Handler

```lua
-- services/example_service/handler.lua
local _M = {}

function _M.handle_get()
    -- Implementation
end

return _M
```

## Configuration Sections

### 1. Service Information

```yaml
x-service-info:
  id: service_id # Unique service identifier
  module: services.module.handler # Lua module path
  enabled: true # Service status
  version: 1.0.0 # Service version
  description: Service description
```

### 2. CORS Configuration

```yaml
cors:
  allow_protocols: # Allowed protocols
    - http
    - https
  allow_headers: # Allowed headers
    - content-type
    - authorization
  allow_credentials: false # Allow credentials
  max_age: 3600 # Preflight cache time

paths:
  /endpoint:
    get:
      cors: # Endpoint-specific CORS
        allow_origins:
          - origin.com
        allow_methods:
          - GET
```

### 3. Route Configuration

```yaml
paths:
  /api/v1/resource:
    get:
      operationId: getResource
      x-route-info:
        id: get_resource # Route identifier
        handler: handle_get # Handler function
        cache: true # Enable caching
        cache_ttl: 3600 # Cache duration
      security:
        - api_key: [] # Security requirements
      parameters: # Route parameters
        - name: id
          in: path
          required: true
          schema:
            type: string
```

### 4. Security Configuration

```yaml
components:
  securitySchemes:
    api_key:
      type: apiKey
      name: X-API-Key
      in: header
    oauth2:
      type: oauth2
      flows:
        clientCredentials:
          tokenUrl: /oauth/token
          scopes:
            read: Read access
            write: Write access
```

## Environment Variables

### 1. Service-Specific Variables

```plaintext
# Service configuration
SERVICE_EXAMPLE_ENABLED=true
SERVICE_EXAMPLE_VERSION=1.0.0
SERVICE_EXAMPLE_CACHE_ENABLED=true
SERVICE_EXAMPLE_CACHE_TTL=3600

# CORS configuration
SERVICE_EXAMPLE_CORS_ENABLED=true
SERVICE_EXAMPLE_CORS_ORIGINS=origin.com
SERVICE_EXAMPLE_CORS_METHODS=GET,POST
```

### 2. Global Service Settings

```plaintext
# Global service settings
SERVICES_DEFAULT_TIMEOUT=30
SERVICES_MAX_BODY_SIZE=10m
SERVICES_CACHE_ENABLED=true
SERVICES_CORS_ENABLED=true
```

## Service Registration

### 1. Automatic Registration

```lua
-- Service registration in init phase
function init()
    local services = {
        "example_service",
        "auth_service",
        "user_service"
    }

    for _, service in ipairs(services) do
        register_service(service)
    end
end
```

### 2. Manual Registration

```lua
-- Manual service registration
local service = require "services.example_service"
local config = {
    id = "example_service",
    routes = {
        {
            path = "/api/v1/example",
            method = "GET",
            handler = service.handle_get
        }
    }
}
register_service(config)
```

## Cache Configuration

### 1. Service-Level Caching

```yaml
x-service-info:
  cache:
    enabled: true
    ttl: 3600
    size: 100m
    methods:
      - GET
      - HEAD
```

### 2. Route-Level Caching

```yaml
paths:
  /api/v1/resource:
    get:
      x-route-info:
        cache:
          enabled: true
          ttl: 3600
          key: "$request_method:$request_uri"
```

## Best Practices

### 1. Service Organization

- Group related endpoints
- Use consistent naming
- Version your APIs
- Document all endpoints

### 2. Security

- Define security schemes
- Use proper authentication
- Implement rate limiting
- Validate inputs

### 3. Performance

- Configure appropriate caching
- Set proper timeouts
- Handle errors gracefully
- Monitor service health

### 4. Maintenance

- Keep specifications updated
- Version control configs
- Monitor service metrics
- Regular security audits

## Example Service

```yaml
# Complete service example
openapi: 3.0.0
info:
  title: User Service
  version: 1.0.0
  description: User management service

x-service-info:
  id: user_service
  module: services.user.handler
  enabled: true
  cors:
    allow_protocols: [http, https]
    allow_headers: [content-type, authorization]
    allow_credentials: false
    max_age: 3600

paths:
  /api/v1/users:
    get:
      operationId: getUsers
      x-route-info:
        id: get_users
        handler: handle_get_users
        cache:
          enabled: true
          ttl: 3600
      security:
        - api_key: []
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
    post:
      operationId: createUser
      x-route-info:
        id: create_user
        handler: handle_create_user
      security:
        - oauth2: [write]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                username:
                  type: string
                email:
                  type: string
                  format: email

components:
  securitySchemes:
    api_key:
      type: apiKey
      name: X-API-Key
      in: header
    oauth2:
      type: oauth2
      flows:
        clientCredentials:
          tokenUrl: /oauth/token
          scopes:
            read: Read access
            write: Write access
```

## Next Steps

- Learn about [Environment Variables](environment.md)
- Explore [NGINX Configuration](nginx.md)
- Read about [Configuration Overview](overview.md)

# Project Structure

The API Gateway follows a modular and organized structure to maintain code clarity and separation of concerns. This document outlines the organization and layout of the codebase.

## Architecture Overview

The gateway follows a modular architecture with several key components:

### 1. Core Layer

- Phase Handlers: Manages NGINX request processing phases
- Route Registry: Handles dynamic route registration and lookup
- Specification Loader: Processes OpenAPI specifications
- Environment Configuration: Manages environment-specific settings

### 2. Middleware Layer

- CORS Middleware: Handles Cross-Origin Resource Sharing
- Router Middleware: Manages request routing
- Request ID Middleware: Adds unique identifiers to requests
- Additional middleware can be easily added

### 3. Service Layer

- Health Service: System health monitoring
- Service-specific handlers
- OpenAPI specification integration

### 4. Configuration Layer

- NGINX configuration
- Service configurations
- Security configurations
- Logging configurations

## Directory Layout

```plaintext
api-gateway/
├── configs/                 # NGINX and application configurations
│   ├── core/               # Core NGINX configurations
│   │   ├── basic.conf      # Basic settings
│   │   ├── env.conf        # Environment variables
│   │   ├── security.conf   # Security settings
│   │   ├── time_maps.conf  # Time zone settings
│   │   ├── error_log.conf  # Error logging settings
│   │   └── debug_log.conf  # Debug logging settings
│   ├── lua/               # Lua-specific configurations
│   │   ├── paths.conf     # Lua module paths
│   │   └── dict.conf      # Shared dictionary definitions
│   ├── locations/          # Location block configurations
│   │   ├── default.conf   # Default location settings
│   │   └── test.conf      # Test endpoint configurations
│   └── nginx.conf          # Main NGINX configuration
│
├── middleware/             # Request/Response middleware components
│   ├── cors/              # CORS middleware
│   │   ├── cors_main.lua  # Main CORS module
│   │   └── cors_utils.lua # CORS utilities
│   ├── router/            # Router middleware
│   │   ├── router.lua     # Router implementation
│   │   └── router_utils.lua # Router utilities
│   └── registry.lua       # Middleware registry
│
├── modules/               # Core functionality modules
│   ├── core/             # Core functionality
│   │   ├── phase_handlers.lua  # NGINX phase handling
│   │   ├── route_registry.lua  # Route management
│   │   ├── spec_loader.lua     # OpenAPI processing
│   │   └── middleware_chain.lua # Middleware management
│   ├── utils/            # Utility functions
│   │   ├── env.lua      # Environment utilities
│   │   └── logger.lua   # Logging utilities
│   └── test/             # Test utilities
│       └── test_helper.lua # Test support functions
│
├── services/             # Service implementations
│   ├── health_service/   # Health check service
│   │   ├── spec.yaml    # OpenAPI specification
│   │   └── handler.lua  # Service handler
│   └── example_service/  # Example service
│       ├── spec.yaml    # Service specification
│       └── handler.lua  # Service implementation
│
├── tests/                # Test suites
│   ├── middleware/       # Middleware tests
│   │   ├── cors_test.lua   # CORS tests
│   │   └── router_test.lua # Router tests
│   ├── modules/          # Module tests
│   │   └── core/        # Core module tests
│   └── services/        # Service tests
│       └── health_test.lua # Health service tests
│
├── logs/                # Application logs
│   ├── access.log       # Standard access logs
│   ├── access.brief.log # Condensed access logs
│   ├── access.human.log # Human-readable access logs
│   ├── error.log       # Error level logs
│   ├── debug.log       # Debug level logs
│   └── info.log        # Information level logs
│
├── Dockerfile           # Container definition
├── docker-compose.yaml  # Container orchestration
├── .env                # Environment variables
└── README.md           # Project documentation
```

## Key Components

### 1. Configuration Files (`/configs`)

The configuration directory contains all NGINX and application configurations:

```plaintext
configs/
├── core/                  # Core configurations
│   ├── basic.conf        # Basic NGINX settings
│   ├── env.conf          # Environment configuration
│   ├── security.conf     # Security settings
│   ├── time_maps.conf    # Time zone maps
│   ├── error_log.conf    # Error logging settings
│   └── debug_log.conf    # Debug logging settings
├── lua/                  # Lua configurations
│   ├── paths.conf       # Lua module paths
│   └── dict.conf        # Shared dictionary definitions
├── locations/            # Location configurations
│   ├── default.conf     # Default location
│   └── test.conf        # Test endpoints
└── nginx.conf            # Main NGINX configuration
```

### 2. Middleware Components (`/middleware`)

Contains request/response processing components with phase-based execution and priority-based ordering:

```plaintext
middleware/
├── cors/                 # CORS handling
│   ├── cors_main.lua    # Main CORS module
│   └── cors_utils.lua   # CORS utilities
├── router/              # Request routing
│   ├── router.lua      # Router implementation
│   └── router_utils.lua # Router utilities
└── registry.lua        # Middleware registration
```

### 3. Core Modules (`/modules`)

Core functionality and utilities with comprehensive error handling and state management:

```plaintext
modules/
├── core/                # Core functionality
│   ├── phase_handlers.lua  # NGINX phase handling
│   ├── route_registry.lua  # Route management
│   ├── spec_loader.lua     # OpenAPI processing
│   └── middleware_chain.lua # Middleware management
├── utils/               # Utility functions
│   ├── env.lua         # Environment utilities
│   └── logger.lua      # Logging utilities
└── test/               # Test utilities
    └── test_helper.lua # Test support functions
```

### 4. Services (`/services`)

Service implementations with OpenAPI specifications and handlers:

```plaintext
services/
├── health_service/      # Health check service
│   ├── spec.yaml       # OpenAPI specification
│   └── handler.lua     # Service implementation
└── example_service/     # Example service
    ├── spec.yaml       # Service specification
    └── handler.lua     # Service implementation
```

### 5. Tests (`/tests`)

Comprehensive test suites for all components:

```plaintext
tests/
├── middleware/          # Middleware tests
│   ├── cors_test.lua   # CORS tests
│   └── router_test.lua # Router tests
├── modules/            # Module tests
│   └── core/          # Core module tests
└── services/          # Service tests
    └── health_test.lua # Health service tests
```

### 6. Logs (`/logs`)

Application logging with different levels and formats:

```plaintext
logs/
├── access.log          # Standard access logs
├── access.brief.log    # Condensed access logs
├── access.human.log    # Human-readable access logs
├── error.log          # Error level logs
├── debug.log          # Debug level logs
└── info.log           # Information level logs
```

## Module Organization

### 1. Core Modules

Each core module should:

- Have a single responsibility
- Export a table of functions
- Include documentation
- Have corresponding tests
- Implement proper error handling
- Use appropriate state management

Example:

```lua
-- modules/core/example_module.lua
local _M = {}

-- Module configuration
local DEFAULT_CONFIG = {
    timeout = 1000,
    retries = 3
}

-- Private functions
local function validate_config(config)
    -- Implementation
end

-- Public interface
function _M.new(config)
    config = config or DEFAULT_CONFIG
    if not validate_config(config) then
        return nil, "Invalid configuration"
    end
    return setmetatable({ config = config }, { __index = _M })
end

return _M
```

### 2. Middleware Modules

Each middleware should:

- Define name and priority
- Implement handle function
- Specify phase
- Include configuration
- Support error handling
- Manage state appropriately

Example:

```lua
-- middleware/example/example.lua
local _M = {
    name = "example",
    priority = 50,
    phase = "access"
}

function _M.handle(self)
    -- Implementation with error handling
    local ok, err = pcall(function()
        -- Middleware logic
    end)

    if not ok then
        ngx.log(ngx.ERR, "Middleware error: ", err)
        return false
    end

    return true
end

return _M
```

### 3. Service Modules

Each service should:

- Have OpenAPI specification
- Implement handlers
- Include documentation
- Have test coverage
- Handle errors appropriately
- Manage state correctly

## Best Practices

### 1. File Organization

- Keep related files together
- Use meaningful directory names
- Maintain consistent structure
- Document organization
- Follow naming conventions

### 2. Module Design

- Single responsibility principle
- Clear module interfaces
- Proper error handling
- Comprehensive documentation
- State management
- Performance optimization

### 3. Testing Structure

- Mirror source structure
- Include unit tests
- Add integration tests
- Maintain test utilities
- Test error conditions
- Performance testing

### 4. Configuration Management

- Group related configs
- Use includes wisely
- Document settings
- Version control
- Environment-based configuration
- Security considerations

## Next Steps

- Review [Coding Standards](coding-standards.md)
- Explore [Best Practices](best-practices.md)
- Read about [Testing](../testing/framework.md)

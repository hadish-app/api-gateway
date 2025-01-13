# Project Structure

## Overview

The API Gateway follows a modular architecture that combines OpenResty's phase-based processing with a flexible middleware system. This hybrid approach provides both structured request processing and extensible middleware capabilities.

## Directory Structure

```
/
├── configs/                 # Configuration files
│   ├── core/               # Core configuration
│   ├── http/              # HTTP-specific configs
│   ├── locations/         # Location-specific configs
│   ├── lua/              # Lua-specific configs
│   └── nginx.conf         # Main nginx configuration
│
├── modules/               # Lua modules
│   ├── core/             # Core functionality
│   │   ├── phase_handlers.lua  # OpenResty phase handlers
│   │   └── middleware_chain.lua # Middleware chain implementation
│   │
│   ├── middleware/       # Middleware components
│   │   ├── registry.lua  # Middleware registration
│   │   └── request_id.lua # Request ID middleware
│   │
│   ├── services/        # Business logic services
│   │   └── health.lua   # Health check service
│   │
│   └── utils/          # Utility functions
│
├── tests/               # Test files
│   ├── core/           # Core tests
│   └── modules/        # Module tests
│       └── middleware/ # Middleware tests
│
├── logs/               # Application logs
│
├── docs/               # Documentation
│   ├── PROJECT_STRUCTURE.md  # This file
│   ├── middleware.md    # Middleware documentation
│   └── ...
│
├── docker-compose.yaml # Docker compose configuration
└── .env               # Environment variables
```

## Key Components

### Core Components

1. **Phase Handlers** (`modules/core/phase_handlers.lua`)

   - Manages OpenResty's request processing phases
   - Coordinates middleware execution
   - Handles initialization and cleanup
   - Manages shared dictionaries and state
   - Implements worker initialization

2. **Middleware Chain** (`modules/core/middleware_chain.lua`)
   - Implements middleware chain execution
   - Manages middleware ordering
   - Handles phase-specific execution
   - Provides error handling

### Middleware System

1. **Registry** (`modules/middleware/registry.lua`)

   - Manages middleware registration
   - Handles phase-specific configuration
   - Validates middleware phases
   - Controls middleware state and priority
   - Supports multi-phase middleware

2. **Request ID Middleware** (`modules/middleware/request_id.lua`)
   - Example of multi-phase middleware
   - Implements access, header_filter, and log phases
   - Demonstrates context sharing between phases

### Configuration

1. **Core Configuration** (`configs/core/`)

   - Basic nginx settings
   - Environment configuration
   - Security settings

2. **Location Configuration** (`configs/locations/`)

   - Endpoint-specific settings
   - Phase handler integration
   - Middleware configuration

3. **Lua Configuration** (`configs/lua/`)
   - Lua-specific settings
   - Shared dictionary configuration
   - Initialization settings

### Shared Dictionaries

The system uses several shared dictionaries for state management:

- `stats`: Runtime statistics
- `metrics`: Performance metrics
- `config_cache`: Configuration cache
- `rate_limit`: Rate limiting data
- `ip_blacklist`: IP blocking list
- `worker_events`: Worker communication

## Phase Processing

The system processes requests through the following phases:

1. **Initialization**

   - `init_by_lua`: One-time initialization
   - `init_worker_by_lua`: Per-worker initialization

2. **Request Processing**
   - `access_by_lua`: Authentication and validation
   - `content_by_lua`: Main request handling
   - `header_filter_by_lua`: Response header processing
   - `body_filter_by_lua`: Response body processing
   - `log_by_lua`: Logging and cleanup

## Testing Structure

1. **Core Tests** (`tests/core/`)

   - Phase handler tests
   - Middleware chain tests
   - Utility function tests

2. **Middleware Tests** (`tests/modules/middleware/`)
   - Registry tests
   - Individual middleware tests
   - Phase interaction tests

## Best Practices

1. **Phase Usage**

   - Use appropriate phases for specific operations
   - Keep phase handlers focused
   - Properly manage state between phases

2. **Middleware Development**

   - Follow single responsibility principle
   - Implement proper phase handling
   - Use appropriate context sharing
   - Handle errors gracefully

3. **Configuration**

   - Keep configurations modular
   - Use environment variables
   - Maintain clear documentation

4. **Testing**
   - Test each phase independently
   - Verify phase interactions
   - Test error conditions
   - Maintain test coverage

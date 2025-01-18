# API Gateway Project Notebook

## Introduction

This notebook provides a comprehensive overview of our API Gateway project, explaining its context, architecture, and implementation details.

## Getting Started Guide

This guide provides a structured learning path for new developers joining the project. The complete onboarding process typically takes 2-3 weeks, depending on prior experience with OpenResty/Lua.

### Step 1: Understanding the Basics (2-3 days)

1. **Project Overview** (Day 1):

   - Read the [Project Context](#project-context) section in this notebook (2 hours)
   - Review the `.env` file to understand basic configuration (1 hour)
   - Explore the project structure (2 hours):
     ```
     api-gateway/
     ├── modules/      # Core implementation
     ├── configs/      # NGINX and app configs
     ├── tests/        # Test suites
     ├── docs/         # Documentation
     └── logs/         # Application logs
     ```

2. **Development Environment** (Day 2):
   - Set up local environment using `docker-compose.yaml` (2 hours)
   - Study environment variables in `.env` (1 hour)
   - Review logging configuration in `configs/nginx.conf` (2 hours)
   - Successfully run the gateway locally (1 hour)

### Step 2: Core Concepts (4-5 days)

1. **Architecture** (2 days):

   - Study [Architecture Overview](#architecture-overview) (4 hours)
   - Review `modules/core/` implementations:
     - Day 1: Study initialization and configuration (4 hours)
     - Day 2: Understand phase handlers and request flow (4 hours)

2. **Middleware System** (2-3 days):
   - Day 1: Read `docs/middleware/IMPLEMENTATION.md` (4 hours)
   - Day 2: Study example middleware:
     - Morning: Request ID middleware (`modules/middleware/request_id.lua`) (4 hours)
     - Afternoon: Rate limiting (`modules/middleware/rate_limit.lua`) (4 hours)
   - Day 3: Practice middleware concepts and ask questions (4-8 hours)

### Step 3: Hands-on Practice (3-4 days)

1. **Testing Framework** (1-2 days):

   - Morning: Read `docs/testing/TESTING.md` (2 hours)
   - Review test examples in `tests/modules/middleware/` (2 hours)
   - Afternoon: Practice running tests (2 hours):
     ```bash
     curl http://localhost:8080/tests/run_all
     ```
   - Day 2: Write sample tests for existing middleware (4-6 hours)

2. **First Tasks** (2 days):
   - Day 1: Review and modify existing middleware (4 hours)
   - Day 1: Practice with logging and debugging (4 hours)
   - Day 2: Implement a simple logging middleware (8 hours)

### Step 4: Advanced Topics (4-5 days)

1. **State Management** (2 days):

   - Day 1: Study and practice with shared dictionaries (4 hours)
   - Day 1: Learn request context handling (4 hours)
   - Day 2: Understand worker processes and state isolation (8 hours)

2. **Performance and Operations** (2-3 days):
   - Day 1: Study logging implementation and patterns (4 hours)
   - Day 2: Learn rate limiting and caching strategies (8 hours)
   - Day 3: Practice error handling patterns (4-8 hours)

### Milestone Checklist

By the end of week 1:

- [ ] Successfully set up development environment
- [ ] Understand basic project structure
- [ ] Grasp OpenResty's phase-based processing
- [ ] Run and modify basic tests

By the end of week 2:

- [ ] Implement a simple middleware
- [ ] Write comprehensive tests
- [ ] Understand state management
- [ ] Handle basic debugging tasks

By the end of week 3:

- [ ] Implement complex middleware
- [ ] Handle advanced error cases
- [ ] Contribute to code reviews
- [ ] Work independently on assigned tasks

### Common Pitfalls and Solutions

1. **Phase Handling**:

   - Always check middleware phase registration
   - Understand phase execution order
   - Review phase-specific limitations

2. **State Management**:
   - Use `ngx.ctx` for request-scoped data
   - Use shared dictionaries for worker-level state
   - Avoid global variables

### Next Steps

1. **Skill Development**:

   - Practice writing middleware
   - Add test cases
   - Review pull requests
   - Study production logs

2. **Further Reading**:
   - OpenResty best practices
   - NGINX configuration patterns
   - Lua performance optimization

### Getting Help

1. **Documentation**:

   - This notebook
   - Code comments
   - Test cases
   - Configuration files

2. **Support**:
   - GitHub issues
   - Code review comments
   - Team discussions
   - Development tools

## Project Context

### Purpose

The API Gateway serves as a central entry point for all API requests, providing:

1. **Request Processing**:

   - Authentication and authorization
   - Request validation and transformation
   - Rate limiting and security controls
   - Request routing and load balancing

2. **Response Handling**:

   - Response transformation
   - Header management
   - Error handling
   - Response caching

3. **Operational Features**:
   - Logging and monitoring
   - Metrics collection
   - Health checks
   - Debugging capabilities

### Technical Stack

1. **Core Technologies**:

   - OpenResty (NGINX + Lua)
   - LuaJIT for high performance
   - NGINX for HTTP server capabilities
   - Lua modules for extensibility

2. **Key Components**:
   - Phase-based request processing
   - Middleware system
   - Shared state management
   - Testing framework

## Architecture Overview

### Design Philosophy

1. **Hybrid Architecture**:

   - Combines NGINX's phase-based processing with middleware patterns
   - Balances structure with flexibility
   - Enables modular feature development
   - Maintains high performance

2. **Design Principles**:
   - Separation of concerns
   - Single responsibility
   - Dependency injection
   - Fail-fast error handling

### Core Systems

1. **Phase Handler System**:

   - Manages request lifecycle
   - Coordinates middleware execution
   - Handles initialization
   - Manages shared resources

2. **Middleware System**:

   - Flexible request/response processing
   - Priority-based execution
   - Route-specific handling
   - Multi-phase support

3. **State Management**:
   - Request-scoped context
   - Worker-level shared state
   - Configuration management
   - Cache management

## Implementation Details

### Request Processing Flow

1. **Initialization**:

   ```lua
   -- Server startup
   init_phase:
       - Load configurations
       - Initialize shared dictionaries
       - Register middleware

   -- Worker startup
   init_worker_phase:
       - Initialize worker state
       - Start background tasks
       - Setup timers
   ```

2. **Request Handling**:

   ```lua
   -- Request phases
   access_phase:
       - Authentication
       - Authorization
       - Rate limiting

   content_phase:
       - Request routing
       - Request processing
       - Response generation

   header_filter_phase:
       - Response header modification
       - Header validation

   body_filter_phase:
       - Response body modification
       - Content transformation

   log_phase:
       - Request logging
       - Metrics collection
       - Cleanup
   ```

### State Management

1. **Request Context**:

   ```lua
   -- Request-scoped data
   ngx.ctx = {
       request_id = uuid.generate(),
       start_time = ngx.now(),
       client_ip = ngx.var.remote_addr,
       route = ngx.var.uri,
       user = nil,  -- Set during authentication
       params = {}  -- Request parameters
   }
   ```

2. **Shared State**:
   ```lua
   -- Worker-level shared dictionaries
   shared_dicts = {
       stats = {         -- Runtime statistics
           requests_total = counter,
           requests_failed = counter,
           average_latency = gauge
       },
       cache = {         -- Response cache
           ttl = 3600,
           max_size = "10m"
       },
       rate_limit = {    -- Rate limiting
           window = 60,
           limit = 100
       }
   }
   ```

## Development Guide

### Adding Features

1. **New Middleware**:

   ```lua
   -- 1. Create middleware module
   -- modules/middleware/feature.lua
   local _M = {
       name = "feature",
       phase = "access",
       priority = 50
   }

   function _M:handle()
       -- Implementation
       return true
   end

   -- 2. Register in registry
   -- modules/core/middleware_registry.lua
   REGISTRY.feature = {
       module = "modules.middleware.feature",
       state = "active",
       priority = 50
   }
   ```

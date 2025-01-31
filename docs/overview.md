# Project Overview

This project is a high-performance API Gateway built on OpenResty (NGINX + Lua), designed to provide a robust and flexible solution for managing, securing, and routing API traffic. The gateway serves as a central entry point for all API requests, handling critical aspects of API management such as request routing, CORS management, and request/response transformation.

---

## Key Features

### 1. Dynamic Route Management

- OpenAPI (Swagger) specification support for service definition
- Dynamic route registration and handling
- Flexible path-based routing system

### 2. Advanced CORS Management

- Comprehensive CORS policy configuration
- Per-route CORS settings
- Strict security validations for CORS headers
- Support for multiple origins, methods, and headers
- Configurable preflight caching

### 3. Security Features

- Built-in security headers
- Request validation
- Origin validation
- Protocol restrictions
- Protection against common web vulnerabilities

### 4. Monitoring and Observability

- Detailed access logging
- Debug logging capabilities
- Request ID tracking
- Health check endpoints
- Error tracking and reporting

### 5. Configuration Management

- Environment-based configuration
- Dynamic configuration updates
- Service-level and route-level configurations
- Shared configuration caching

---

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

---

## Technology Stack

### 1. Core Technologies

- OpenResty 1.21.4.1 (NGINX + LuaJIT)
- Alpine Linux (Base Container Image)

### 2. Key Dependencies

- lua-resty-jit-uuid: UUID generation
- luafilesystem: File system operations
- lyaml: YAML parsing for OpenAPI specs
- cjson: JSON handling

### 3. Development Tools

- Docker and Docker Compose for containerization
- Shell and Lua-based testing framework
- Automated testing support

### 4. Runtime Environment

- Containerized deployment
- Environment variable configuration
- Volume mounting for configuration and modules
- Hot-reload capability for development

---

## Summary

This API Gateway is designed to be highly performant, secure, and maintainable, with a focus on providing a robust platform for API management and routing. The modular architecture allows for easy extension and customization while maintaining strong security practices and efficient request processing.

---

## Next Steps

- Learn about the [Architecture](architecture/overview.md)
- Start [Development](development/getting-started.md)
- Read the [Configuration Guide](configuration/overview.md)

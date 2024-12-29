# Hadish API Gateway - Project Structure

## Overview

This document provides a comprehensive overview of the Hadish API Gateway project structure, explaining the purpose and organization of each directory and key files.

## Root Directory

- `docker-compose.yaml` - Main container orchestration configuration
- `.env` - Environment variables configuration
- `.dockerignore` - Docker build exclusions
- `.gitignore` - Git exclusions
- `api-gateway.code-workspace` - VS Code workspace settings

## Directories

### `/configs`

Configuration files for OpenResty/Nginx.

#### `/configs/core`

Core Nginx configurations:

- `access_log.conf` - Access logging configuration
- `basic.conf` - Basic Nginx settings
- `debug_log.conf` - Debug logging settings
- `env.conf` - Environment variable handling
- `error_log.conf` - Error logging configuration
- `ipban.conf` - IP banning rules
- `mime.conf` - MIME type definitions
- `ratelimit.conf` - Rate limiting rules
- `security.conf` - Security settings
- `time_maps.conf` - Time-based configurations

#### `/configs/locations`

Nginx location blocks for different endpoints:

- `admin.conf` - Admin API endpoints
- `debug.conf` - Debugging endpoints
- `default.conf` - Default location handling
- `errors.conf` - Error page configurations
- `health.conf` - Health check endpoints
- `test.conf` - Testing endpoints

#### `/configs/lua`

Lua-specific configurations:

- `dict.conf` - Shared dictionary definitions
- `init.conf` - Lua initialization
- `paths.conf` - Lua path configurations

### `/modules`

Lua modules implementing the gateway functionality.

#### `/modules/core`

Core functionality:

- `config.lua` - Configuration management
- `init.lua` - Core initialization
- `middleware_chain.lua` - Middleware handling

#### `/modules/middleware`

Request processing middleware:

- `/request` - Request processing middleware
  - `/validations` - Request validation middleware
  - `/sanitizations` - Request sanitization middleware
- `registry.lua` - Middleware registration and management
- `request_id.lua` - Request ID generation and tracking

#### `/modules/services`

Service-specific handlers:

- `admin.lua` - Admin service implementation
- `health.lua` - Health check implementation

#### `/modules/utils`

Utility functions:

- `env.lua` - Environment variable utilities
- `type_conversion.lua` - Data type conversion utilities

### `/tests`

Test suites and utilities.

#### `/tests/core`

- `test_utils.lua` - Testing utilities and helpers

#### `/tests/modules`

Module-specific tests:

- `/core` - Core module tests
- `/services` - Service tests
- `/utils` - Utility function tests

### `/docs`

Project documentation:

- `CONTEXT.md` - Project context and requirements
- `TESTING.md` - Testing documentation
- `PROJECT_STRUCTURE.md` - This document

## Key Features Organization

### Health Checking

- Configuration: `/configs/locations/health.conf`
- Implementation: `/modules/services/health.lua`
- Tests: `/tests/modules/services/health_test.lua`

### Security Features

- CORS: `/modules/middleware/security/cors.lua`
- IP Banning: `/modules/middleware/security/ipban.lua`
- Rate Limiting: `/modules/middleware/security/ratelimit.lua`
- Request Validations: `/modules/middleware/request/validations/`
  - Path Traversal Validation
  - Content Validation
  - Length Validation
  - Method Validation
  - Header Validation
- Request Sanitizations: `/modules/middleware/request/sanitizations/`
  - XSS Protection
  - SQL Injection Protection
  - Header Sanitization

### Monitoring

- Logging: Using Nginx built-in logging system
  - Access logs configuration: `configs/core/access_log.conf`
  - Error logs configuration: `configs/core/error_log.conf`
  - Debug logs configuration: `configs/core/debug_log.conf`
- Metrics: `/modules/middleware/metrics/`

## Configuration Flow

1. Environment variables (`.env`)
2. Nginx main config (`configs/nginx.conf`)
3. Core configs (`configs/core/`)
4. Location configs (`configs/locations/`)
5. Lua initialization (`configs/lua/`)

## Testing Organization

- Unit Tests: Individual module tests in `/tests/modules/`
- Integration Tests: Service-level tests
- Test Utilities: Common test functions in `/tests/core/`

## Development Workflow

1. Configuration changes in `/configs`
2. Implementation in `/modules`
3. Testing in `/tests`
4. Documentation in `/docs`

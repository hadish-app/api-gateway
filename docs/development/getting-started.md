# Getting Started

This guide will help you set up your development environment and start working with the API Gateway.

## Prerequisites

### 1. Required Software

- Docker (20.10.0 or higher)
- Docker Compose (2.0.0 or higher)
- Git
- Text editor with Lua support (VSCode, Sublime, etc.)

### 2. Recommended Knowledge

- Basic understanding of NGINX/OpenResty
- Familiarity with Lua programming
- Understanding of RESTful APIs
- Basic Docker knowledge

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/api-gateway.git
cd api-gateway
```

### 2. Environment Setup

```bash
# Copy environment template
cp sample.env .env

# Edit environment variables
vim .env
```

### 3. Build and Run

```bash
# Build the containers
docker-compose build

# Start the services
docker-compose up -d
```

### 4. Verify Installation

```bash
# Check service status
docker-compose ps

# Check logs
docker-compose logs -f api-gateway

# Test the health endpoint
curl http://localhost:8080/health
```

## Project Structure

```plaintext
api-gateway/
├── configs/             # NGINX and application configurations
├── middleware/          # Request/Response middleware components
├── modules/             # Core functionality modules
├── services/           # Service implementations
├── tests/              # Test suites and utilities
├── logs/               # Application logs
├── Dockerfile          # Container definition
├── docker-compose.yaml # Container orchestration
└── .env               # Environment variables
```

## Development Workflow

### 1. Local Development

```bash
# Start with development configuration
docker-compose -f docker-compose.dev.yaml up -d

# Enable hot reload
export LUA_CODE_CACHE=off

# Watch logs
docker-compose logs -f api-gateway
```

### 2. Making Changes

1. Create a new branch:

```bash
git checkout -b feature/your-feature
```

2. Make your changes
3. Run tests:

```bash
docker-compose exec api-gateway /usr/local/openresty/nginx/tests/run.sh
```

4. Commit your changes:

```bash
git add .
git commit -m "feat: add new feature"
```

### 3. Testing Changes

```bash
# Run all tests
docker-compose exec api-gateway /usr/local/openresty/nginx/tests/run.sh

# Run specific test file
docker-compose exec api-gateway /usr/local/openresty/nginx/tests/run.sh test_file.lua

# Run with coverage
docker-compose exec api-gateway /usr/local/openresty/nginx/tests/run.sh --coverage
```

## Creating a New Service

### 1. Service Structure

```plaintext
services/new_service/
├── spec.yaml           # OpenAPI specification
└── handler.lua         # Service implementation
```

### 2. OpenAPI Specification

```yaml
# services/new_service/spec.yaml
openapi: 3.0.0
info:
  title: New Service
  version: 1.0.0
  description: New service description

x-service-info:
  id: new_service
  module: services.new_service.handler
  enabled: true

paths:
  /api/v1/resource:
    get:
      operationId: getResource
      x-route-info:
        id: get_resource
        handler: handle_get
```

### 3. Service Handler

```lua
-- services/new_service/handler.lua
local _M = {}

function _M.handle_get()
    -- Implementation
    return true
end

return _M
```

## Adding Middleware

### 1. Middleware Structure

```lua
-- middleware/new_middleware.lua
local _M = {
    name = "new_middleware",
    priority = 50,
    phase = "access",
}

function _M.handle(self)
    -- Implementation
    return true
end

return _M
```

### 2. Register Middleware

```lua
-- Add to middleware/registry.lua
local registry = {
    new_middleware = {
        module = "middleware.new_middleware",
        enabled = true,
        phase = "access",
        priority = 50
    }
}
```

## Development Tools

### 1. Useful Commands

```bash
# Rebuild containers
docker-compose build --no-cache

# Restart services
docker-compose restart

# View logs
docker-compose logs -f

# Access container shell
docker-compose exec api-gateway sh

# Check NGINX configuration
docker-compose exec api-gateway nginx -t

# Reload NGINX
docker-compose exec api-gateway nginx -s reload
```

### 2. Debug Tools

```bash
# Enable debug logging
export LOG_LEVEL=debug

# Monitor access logs
tail -f logs/access.log

# Monitor error logs
tail -f logs/error.log

# Test endpoints
curl -v http://localhost:8080/health
```

## Best Practices

### 1. Code Organization

- Follow the project structure
- Use meaningful file names
- Group related functionality
- Keep modules focused

### 2. Development Process

- Create feature branches
- Write tests first
- Document your code
- Review changes locally

### 3. Testing

- Write unit tests
- Test error cases
- Check performance
- Verify configurations

### 4. Debugging

- Use appropriate log levels
- Add debug logging
- Check error logs
- Test incrementally

## Common Issues

### 1. Configuration

- Check environment variables
- Verify NGINX configuration
- Validate service specifications
- Check file permissions

### 2. Runtime

- Monitor error logs
- Check service status
- Verify network connectivity
- Validate request/response

## Next Steps

- Read the [Project Structure](project-structure.md) guide
- Learn about [Coding Standards](coding-standards.md)
- Explore [Best Practices](best-practices.md)
- Review [Testing](../testing/framework.md) documentation

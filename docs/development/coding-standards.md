# Coding Standards

This document outlines the coding standards and conventions for the API Gateway project. Following these standards ensures code consistency, maintainability, and readability across the codebase.

## Lua Code Style

### 1. Naming Conventions

#### Variables and Functions

```lua
-- Local variables: snake_case
local my_variable = "value"

-- Global variables: UPPER_SNAKE_CASE (avoid when possible)
MY_GLOBAL = "value"

-- Function names: snake_case
local function calculate_total(a, b)
    return a + b
end

-- Private functions: prefix with underscore
local function _internal_helper()
    -- Implementation
end
```

#### Modules and Classes

```lua
-- Module names: snake_case
local my_module = {}

-- Class-like tables: PascalCase
local MyClass = {
    new = function(self)
        return setmetatable({}, { __index = self })
    end
}
```

### 2. Code Layout

#### Indentation and Spacing

- Use 4 spaces for indentation (not tabs)
- One space after commas in parameter lists
- No space between function name and opening parenthesis
- One space around operators

```lua
-- Good
local function process_request(name, value)
    local result = name .. " = " .. value
    return result
end

-- Bad
local function process_request ( name,value )
    local result=name.." = "..value
    return result
end
```

#### Line Length and Breaks

- Maximum line length: 80 characters
- Break long lines at logical points
- Align broken lines with the opening delimiter

```lua
-- Good
local very_long_function_call = some_module.some_function(
    first_parameter,
    second_parameter,
    third_parameter
)

-- Bad
local very_long_function_call = some_module.some_function(first_parameter, second_parameter,
third_parameter)
```

### 3. Comments and Documentation

#### Function Documentation

```lua
--- Brief description of the function
-- Detailed description if needed
-- @param name (string) Description of the parameter
-- @param value (number) Description of the parameter
-- @return (boolean) Description of the return value
-- @return (string|nil) Description of error message if any
local function validate_input(name, value)
    -- Implementation
end
```

#### Module Documentation

```lua
--- Module description
-- @module my_module
-- @author Author Name
-- @license MIT
-- @copyright 2024

local _M = {}

-- Rest of the module code
```

## OpenAPI Specification Style

### 1. File Structure

```yaml
openapi: 3.0.0
info:
  title: Service Name
  version: 1.0.0
  description: |
    Detailed service description
    spanning multiple lines

x-service-info:
  id: service_id
  module: services.service_name.handler
```

### 2. Path Organization

```yaml
paths:
  /resource:
    get:
      summary: Brief description
      description: Detailed description
      operationId: getResource
      x-route-info:
        id: get_resource
        handler: handle_get
```

### 3. Schema Definitions

```yaml
components:
  schemas:
    ResourceModel:
      type: object
      required:
        - id
        - name
      properties:
        id:
          type: string
          format: uuid
          description: Resource identifier
        name:
          type: string
          minLength: 1
          maxLength: 100
          description: Resource name
```

## NGINX Configuration Style

### 1. File Organization

```nginx
# Use descriptive block names
http {
    # Group related settings
    # Include brief explanation for non-obvious settings

    # Security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Performance tuning
    worker_connections 1024;
    keepalive_timeout 65;
}
```

### 2. Location Blocks

```nginx
# Group locations logically
# Include comments for complex configurations

location / {
    # Security headers
    add_header X-Frame-Options "DENY";
    add_header X-Content-Type-Options "nosniff";

    # Proxy settings
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

## Git Commit Standards

### 1. Commit Message Format

```
type(scope): subject

body

footer
```

- Type: feat, fix, docs, style, refactor, test, chore
- Scope: component affected (optional)
- Subject: brief description in present tense
- Body: detailed description (optional)
- Footer: breaking changes, issue references (optional)

### 2. Examples

```
feat(middleware): add rate limiting middleware

- Implements token bucket algorithm
- Adds configuration options
- Includes unit tests

Closes #123
```

```
fix(core): resolve memory leak in route registry

Memory was not being properly freed when removing routes.
Added cleanup in route deregistration process.

BREAKING CHANGE: Route removal now requires explicit cleanup
```

## Testing Standards

### 1. Test Structure

```lua
-- Test file organization
describe("Module name", function()
    -- Setup
    before_each(function()
        -- Common setup
    end)

    -- Test cases
    it("should perform specific action", function()
        -- Test implementation
    end)

    -- Cleanup
    after_each(function()
        -- Common cleanup
    end)
end)
```

### 2. Naming Conventions

```lua
-- Test files: match source file name with _test suffix
-- source: my_module.lua
-- test: my_module_test.lua

-- Test descriptions: should + expected behavior
it("should return error for invalid input")
it("should process valid request successfully")
```

## Error Handling Standards

### 1. Error Format

```lua
-- Return nil and error message for failures
function process_data(input)
    if not validate(input) then
        return nil, "Invalid input format"
    end

    local result, err = do_processing(input)
    if err then
        return nil, string.format("Processing failed: %s", err)
    end

    return result
end
```

### 2. Error Logging

```lua
-- Use appropriate log levels
local function handle_request()
    local data, err = process_input()
    if err then
        ngx.log(ngx.ERR, "Failed to process input: ", err)
        return ngx.exit(ngx.HTTP_BAD_REQUEST)
    end
end
```

## Code Review Standards

### 1. Review Checklist

- Code follows style guide
- Tests are included and pass
- Documentation is updated
- Error handling is appropriate
- Performance considerations addressed
- Security implications considered

### 2. Review Comments

- Be specific and constructive
- Reference relevant standards
- Suggest improvements
- Acknowledge good practices

## Maintenance

These standards should be:

1. Regularly reviewed and updated
2. Automatically enforced where possible
3. Included in onboarding documentation
4. Referenced in code review processes

## Tools and Automation

### 1. Linting

- Use `luacheck` for static analysis
- Configure IDE/editor integration
- Run in CI/CD pipeline

### 2. Formatting

- Use automatic formatters
- Configure pre-commit hooks
- Maintain consistent settings

## Next Steps

- Review [Best Practices](best-practices.md)
- Explore [Testing Framework](../testing/framework.md)
- Set up your development environment

# Environment Variables

The API Gateway uses environment variables as the primary configuration source, providing a flexible and secure way to configure the system.

## Environment File Structure

### 1. File Location

- Primary: `.env` in project root
- Development: `development.env`
- Production: `production.env`
- Sample: `sample.env`

### 2. Variable Naming Convention

```plaintext
SECTION_SUBSECTION_KEY=value
```

Example sections:

- `SERVER_*`: Server settings
- `SECURITY_*`: Security settings
- `LOGGING_*`: Logging settings
- `CORS_*`: CORS settings
- `CACHE_*`: Cache settings

## Configuration Sections

### 1. Server Configuration

```plaintext
# Server Settings
SERVER_PORT=8080
SERVER_HOST=0.0.0.0
SERVER_WORKER_PROCESSES=auto
SERVER_WORKER_CONNECTIONS=1024
SERVER_KEEPALIVE_TIMEOUT=65

# SSL/TLS Settings
SERVER_SSL_ENABLED=true
SERVER_SSL_CERTIFICATE=/path/to/cert.pem
SERVER_SSL_KEY=/path/to/key.pem
```

### 2. Security Configuration

```plaintext
# Rate Limiting
SECURITY_RATE_LIMIT_REQUESTS=100
SECURITY_RATE_LIMIT_WINDOW=60

# IP Blocking
SECURITY_IP_BLACKLIST_ENABLED=true
SECURITY_IP_WHITELIST_ENABLED=false

# Security Headers
SECURITY_HEADERS_HSTS_ENABLED=true
SECURITY_HEADERS_XSS_PROTECTION=1
```

### 3. CORS Configuration

```plaintext
# CORS Settings
CORS_ENABLED=true
CORS_ALLOW_ORIGINS=http://example.com,https://api.example.com
CORS_ALLOW_METHODS=GET,POST,PUT,DELETE,OPTIONS
CORS_ALLOW_HEADERS=Content-Type,Authorization
CORS_ALLOW_CREDENTIALS=false
CORS_MAX_AGE=3600
```

### 4. Logging Configuration

```plaintext
# Logging Settings
LOGGING_LEVEL=info
LOGGING_FORMAT=json
LOGGING_OUTPUT=file
LOGGING_PATH=/var/log/api-gateway
LOGGING_MAX_SIZE=100M
LOGGING_MAX_FILES=10
```

### 5. Cache Configuration

```plaintext
# Cache Settings
CACHE_ENABLED=true
CACHE_TTL=3600
CACHE_SIZE=100m
CACHE_INACTIVE=600s
```

## Value Types and Conversion

### 1. Boolean Values

```plaintext
FEATURE_ENABLED=true    # Converts to true
FEATURE_ENABLED=1       # Converts to true
FEATURE_ENABLED=yes     # Converts to true
FEATURE_ENABLED=false   # Converts to false
FEATURE_ENABLED=0       # Converts to false
FEATURE_ENABLED=no      # Converts to false
```

### 2. Numeric Values

```plaintext
PORT=8080              # Integer
TIMEOUT=30.5          # Float
LIMIT=-1              # Negative integer
```

### 3. String Values

```plaintext
HOST=localhost
PATH=/var/log
ORIGINS=http://example.com,https://api.example.com
```

### 4. Array Values

```plaintext
# Comma-separated strings
ALLOWED_ORIGINS=http://example.com,https://api.example.com

# Space-separated strings
ALLOWED_METHODS=GET POST PUT DELETE
```

## Environment Processing

### 1. Loading Process

```lua
-- env.lua
local function load_environment()
    local env = {}

    -- Load from file
    for line in io.lines(".env") do
        local key, value = parse_env_line(line)
        if key then
            env[key] = process_value(value)
        end
    end

    return env
end
```

### 2. Value Processing

```lua
local function process_value(value)
    -- Boolean conversion
    if value:lower() == "true" or value == "1" or value:lower() == "yes" then
        return true
    elseif value:lower() == "false" or value == "0" or value:lower() == "no" then
        return false
    end

    -- Number conversion
    local number = tonumber(value)
    if number then
        return number
    end

    -- Array conversion
    if value:find(",") then
        local array = {}
        for item in value:gmatch("[^,]+") do
            table.insert(array, item:match("^%s*(.-)%s*$"))
        end
        return array
    end

    -- Return as string
    return value
end
```

## Best Practices

### 1. Security

- Never commit `.env` files
- Use `.env.sample` for documentation
- Rotate sensitive values regularly
- Use secure storage for production

### 2. Organization

- Group related variables
- Use consistent naming
- Document all variables
- Keep sections organized

### 3. Validation

- Validate required variables
- Check value types
- Verify dependencies
- Validate ranges

### 4. Development

- Use different files per environment
- Document default values
- Provide clear examples
- Include validation rules

## Example Configuration

```plaintext
# Server Configuration
SERVER_PORT=8080
SERVER_HOST=0.0.0.0
SERVER_WORKER_PROCESSES=auto

# Security Configuration
SECURITY_RATE_LIMIT_ENABLED=true
SECURITY_RATE_LIMIT_REQUESTS=100
SECURITY_RATE_LIMIT_WINDOW=60

# CORS Configuration
CORS_ENABLED=true
CORS_ALLOW_ORIGINS=http://example.com,https://api.example.com
CORS_ALLOW_METHODS=GET,POST,PUT,DELETE,OPTIONS

# Logging Configuration
LOGGING_LEVEL=info
LOGGING_FORMAT=json
LOGGING_OUTPUT=file

# Cache Configuration
CACHE_ENABLED=true
CACHE_TTL=3600
CACHE_SIZE=100m
```

## Next Steps

- Learn about [NGINX Configuration](nginx.md)
- Explore [Service Configuration](services.md)
- Read the [Configuration Overview](overview.md)

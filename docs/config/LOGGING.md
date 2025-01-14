# Logging Configuration

## Overview

The API Gateway implements a comprehensive logging system with multiple log formats, levels, and outputs. This guide covers the logging configuration, formats, and best practices.

## Log Files Structure

```
logs/
├── access.log          # JSON-formatted access logs
├── access.human.log    # Human-readable detailed access logs
├── access.brief.log    # Brief access logs for quick debugging
├── error.log          # Error-level logs
├── debug.log          # Debug-level detailed logs
└── info.log           # Information-level logs
```

## Configuration Files

### 1. Error Logging (`configs/core/error_log.conf`)

Main context error logging configuration:

```nginx
# Write to both file and stderr for debugging
error_log /usr/local/openresty/nginx/logs/error.log error;
error_log /dev/stderr error;
```

### 2. Debug Logging (`configs/core/debug_log.conf`)

Debug and info level logging configuration:

```nginx
# Error levels for different purposes
error_log /usr/local/openresty/nginx/logs/error.log error; # Serious errors only
error_log /usr/local/openresty/nginx/logs/debug.log debug; # Detailed debugging
error_log /usr/local/openresty/nginx/logs/info.log info;   # General information
error_log /dev/stderr notice;                              # Important notices to console
error_log /dev/stdout debug;                               # Real-time debug output
```

### 3. Access Logging (`configs/core/access_log.conf`)

HTTP context access logging with multiple formats:

```nginx
# Log formats
log_format json_main escape=json '{
    "timestamp":"$time_iso8601",
    "request_id":"$sent_http_x_request_id",
    "client":"$remote_addr",
    "user":"$remote_user",
    "request":"$request",
    "status":$status,
    "bytes_sent":$body_bytes_sent,
    "referer":"$http_referer",
    "user_agent":"$http_user_agent",
    "forwarded_for":"$http_x_forwarded_for",
    "request_time":$request_time
}';

log_format detailed '[$time_iso8601] request_id=$sent_http_x_request_id client=$remote_addr user=$remote_user request="$request" '
                    'status=$status bytes_sent=$body_bytes_sent referer="$http_referer" '
                    'user_agent="$http_user_agent" forwarded="$http_x_forwarded_for" '
                    'request_time=$request_time';

log_format brief '[$time_iso8601] [$sent_http_x_request_id] $request_method $uri -> $status ($request_time sec)';

# Access logs with different formats
access_log /usr/local/openresty/nginx/logs/access.log json_main;
access_log /usr/local/openresty/nginx/logs/access.human.log detailed;
access_log /usr/local/openresty/nginx/logs/access.brief.log brief;
access_log /dev/stdout brief;
```

## Log Formats

### 1. JSON Format (Machine-Readable)

Used in `access.log`:

```json
{
  "timestamp": "2024-01-10T12:34:56+00:00",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "client": "192.168.1.1",
  "user": "-",
  "request": "GET /api/users HTTP/1.1",
  "status": 200,
  "bytes_sent": 1234,
  "referer": "https://example.com",
  "user_agent": "Mozilla/5.0...",
  "forwarded_for": "10.0.0.1",
  "request_time": 0.005
}
```

### 2. Detailed Format (Human-Readable)

Used in `access.human.log`:

```
[2024-01-10T12:34:56+00:00] request_id=550e8400-e29b-41d4-a716-446655440000 client=192.168.1.1 user=- request="GET /api/users HTTP/1.1" status=200 bytes_sent=1234 referer="https://example.com" user_agent="Mozilla/5.0..." forwarded="10.0.0.1" request_time=0.005
```

### 3. Brief Format (Quick Debugging)

Used in `access.brief.log` and stdout:

```
[2024-01-10T12:34:56+00:00] [550e8400-e29b-41d4-a716-446655440000] GET /api/users -> 200 (0.005 sec)
```

## Log Levels

1. **error**: Serious errors that need immediate attention
2. **notice**: Important system events
3. **info**: General information about system operation
4. **debug**: Detailed information for debugging

## Logging in Code

### 1. Basic Logging

```lua
-- Error logging
ngx.log(ngx.ERR, "Failed to process request: ", err)

-- Notice logging
ngx.log(ngx.NOTICE, "Configuration reloaded")

-- Info logging
ngx.log(ngx.INFO, "Request processed successfully")

-- Debug logging
ngx.log(ngx.DEBUG, "Processing request with ID: ", request_id)
```

### 2. Structured Logging

```lua
-- Example of structured error logging
local function log_error(context, message, details)
    local error_info = {
        timestamp = ngx.time(),
        context = context,
        message = message,
        details = details,
        request_id = ngx.ctx.request_id
    }
    ngx.log(ngx.ERR, require("cjson").encode(error_info))
end

-- Usage
log_error("auth", "Authentication failed", {
    user = "example",
    reason = "invalid_token"
})
```

### 3. Request Context Logging

```lua
-- Example from request_id middleware
function _M.log:handle()
    ngx.log(ngx.INFO, string.format(
        "Request completed - ID: %s, Method: %s, URI: %s, Status: %d",
        ngx.ctx.request_id,
        ngx.req.get_method(),
        ngx.var.request_uri,
        ngx.status
    ))
    return true
end
```

## Environment Variables

| Variable               | Type    | Default  | Description           |
| ---------------------- | ------- | -------- | --------------------- |
| LOGGING_LEVEL          | string  | "notice" | Global log level      |
| LOGGING_BUFFER_SIZE    | string  | "4k"     | Log buffer size       |
| LOGGING_FLUSH_INTERVAL | string  | "1s"     | Log flush interval    |
| LOGGING_ACCESS_LOG     | boolean | true     | Enable access logging |
| LOGGING_ERROR_LOG      | boolean | true     | Enable error logging  |

## Best Practices

1. **Log Levels**:

   - Use appropriate log levels for different types of information
   - Reserve ERROR for actual errors
   - Use DEBUG for detailed troubleshooting
   - Keep NOTICE and INFO clean and meaningful

2. **Performance**:

   - Use buffer settings for high-traffic scenarios
   - Consider log rotation for large files
   - Monitor log file sizes
   - Use appropriate flush intervals

3. **Security**:

   - Never log sensitive information
   - Sanitize user input in logs
   - Implement log rotation
   - Consider log file permissions

4. **Debugging**:

   - Include request IDs in all logs
   - Add context to error messages
   - Use structured logging where appropriate
   - Keep debug logs detailed but clean

5. **Maintenance**:
   - Implement log rotation
   - Monitor log file sizes
   - Clean up old logs
   - Archive important logs

## Example Scenarios

### 1. Error Handling

```lua
-- Example of error handling with proper logging
function process_request()
    local ok, err = pcall(function()
        -- Some risky operation
    end)

    if not ok then
        ngx.log(ngx.ERR, string.format(
            "Failed to process request [%s]: %s",
            ngx.ctx.request_id or "no-id",
            err
        ))
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
end
```

### 2. Audit Logging

```lua
-- Example of audit logging
function audit_log(action, success, details)
    local audit_info = {
        timestamp = ngx.time(),
        request_id = ngx.ctx.request_id,
        client_ip = ngx.var.remote_addr,
        action = action,
        success = success,
        details = details
    }

    ngx.log(ngx.INFO, require("cjson").encode(audit_info))
end

-- Usage
audit_log("user_login", true, {
    user = "example",
    method = "password"
})
```

### 3. Performance Monitoring

```lua
-- Example of performance logging
function log_performance(operation, start_time)
    local duration = ngx.now() - start_time
    ngx.log(ngx.INFO, string.format(
        "Performance - Operation: %s, Duration: %.3f ms, Request-ID: %s",
        operation,
        duration * 1000,
        ngx.ctx.request_id or "no-id"
    ))
end

-- Usage
local start = ngx.now()
-- Some operation
log_performance("database_query", start)
```

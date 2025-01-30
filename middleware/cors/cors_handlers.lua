local cjson = require "cjson"
local config = require "middleware.cors.cors_config"
local validators = require "middleware.cors.cors_validators"
local utils = require "middleware.cors.cors_utils"
local ngx = ngx

-- Cached error status codes for better performance
local ERROR_STATUSES = {
    FORBIDDEN = ngx.HTTP_FORBIDDEN,
    BAD_REQUEST = ngx.HTTP_BAD_REQUEST,
    INTERNAL_ERROR = ngx.HTTP_INTERNAL_SERVER_ERROR
}

-- Cache common security headers
local SECURITY_HEADERS = {
    ["X-Content-Type-Options"] = "nosniff",
    ["X-Frame-Options"] = "DENY",
    ["X-XSS-Protection"] = "1; mode=block"
}

-- Helper function to set error response
local function set_error_response(cors_ctx, status, err_msg, details)
    if not cors_ctx.validation_failed then  -- Only set error once
        cors_ctx.validation_failed = true
        cors_ctx.error_message = validators.format_cors_error(err_msg, details)
        
        -- Set response headers only once
        ngx.status = status
        ngx.ctx.skip_response_body = true
        
        -- Clear any existing CORS headers
        for k, _ in pairs(ngx.header) do
            if k:lower():find("^access%-control%-", 1, true) then
                ngx.header[k] = nil
            end
        end
        
        -- Log error with context
        ngx.log(ngx.WARN, string.format("[cors] Validation failed: %s. %s", err_msg, cors_ctx.log_context))
        ngx.log(ngx.ERR, string.format("[cors] %s", cors_ctx.error_message))
    end
end

local function check_credentials(cors_ctx)
    -- Cache headers table to avoid repeated lookups
    local headers = cors_ctx.headers
    local log_context = cors_ctx.log_context
    
    -- Use single return variable for better performance
    local has_credentials = headers["Cookie"] or 
                          headers["Authorization"] or 
                          ngx.var.ssl_client_verify == "SUCCESS"
    
    if has_credentials then
        ngx.log(ngx.DEBUG, string.format("[cors] Request contains credentials. %s", log_context))
    end
    
    return has_credentials
end

local function validate_origin(cors_ctx)
    ngx.log(ngx.DEBUG, string.format("[cors] Origin validation started. origin=%s. %s", 
        cors_ctx.origin, cors_ctx.log_context))
    
    -- Check if origin is present and valid
    if not cors_ctx.origin or cors_ctx.origin == "" then
        set_error_response(cors_ctx, ngx.HTTP_FORBIDDEN, "Missing or empty Origin header", "Origin header is required for CORS requests")
        return false
    end
    
    -- Check if origin is allowed
    if not validators.is_origin_allowed(cors_ctx) then
        set_error_response(cors_ctx, ngx.HTTP_FORBIDDEN, "Origin not allowed", cors_ctx.origin)
        return false
    end
    
    if cors_ctx.has_credentials then
        -- If request has credentials, wildcard origin is not allowed
        if cors_ctx.origin == "*" or cors_ctx.config.allow_origin == "*" then
            set_error_response(cors_ctx, ngx.HTTP_FORBIDDEN, 
                "Invalid CORS configuration", 
                "Wildcard origin not allowed with credentials")
            return false
        end
        
        -- If request has credentials but they're not allowed
        if not cors_ctx.config.allow_credentials then
            -- Don't reject the request, just don't send Access-Control-Allow-Credentials
            ngx.log(ngx.DEBUG, string.format("[cors] Credentials present but not allowed. %s", cors_ctx.log_context))
        end
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Origin validation successful. %s", cors_ctx.log_context))
    return true
end

local function set_security_headers()
    for name, value in pairs(SECURITY_HEADERS) do
        ngx.header[name] = value
    end
end

local function handle_preflight_response(cors_ctx)
    ngx.log(ngx.DEBUG, string.format("[cors] Setting preflight response headers. %s", cors_ctx.log_context))
    
    local headers = ngx.header
    -- Set required CORS headers using cached config values
    headers["Access-Control-Allow-Origin"] = validators.sanitize_header(cors_ctx.origin)
    headers["Access-Control-Allow-Methods"] = cors_ctx.config.cache.allow_methods_str
    headers["Access-Control-Allow-Headers"] = cors_ctx.config.cache.allow_headers_str
    headers["Access-Control-Max-Age"] = cors_ctx.config.max_age
    headers["Vary"] = "Origin, Access-Control-Request-Method, Access-Control-Request-Headers"
    
    -- Set credentials header if needed
    if cors_ctx.has_credentials and cors_ctx.config.allow_credentials then
        headers["Access-Control-Allow-Credentials"] = "true"
    end
    
    -- Set security headers
    set_security_headers()
    
    -- Set response status and clear body
    ngx.status = ngx.HTTP_NO_CONTENT
    headers["Content-Length"] = 0
    ngx.ctx.skip_response_body = true
end

local function handle_cors_response(cors_ctx)
    ngx.log(ngx.DEBUG, string.format("[cors] Setting CORS response headers. %s", cors_ctx.log_context))
    
    local headers = ngx.header
    -- Set required CORS headers
    headers["Access-Control-Allow-Origin"] = validators.sanitize_header(cors_ctx.origin)
    headers["Vary"] = "Origin"
    
    -- Set exposed headers if configured (using cached value)
    if cors_ctx.config.cache.expose_headers_str then
        headers["Access-Control-Expose-Headers"] = cors_ctx.config.cache.expose_headers_str
    end
    
    -- Set credentials header if needed
    if cors_ctx.has_credentials and cors_ctx.config.allow_credentials then
        headers["Access-Control-Allow-Credentials"] = "true"
    end
    
    -- Set security headers
    set_security_headers()
end

local function get_cors_context()
    local headers = ngx.req.get_headers()
    local method = ngx.req.get_method()
    local request_id = ngx.ctx.request_id or "none"
    local remote_addr = ngx.var.remote_addr
    local path = ngx.var.request_uri
    
    -- Pre-compute values that are used multiple times
    local is_options = method == "OPTIONS"
    local origin = headers["Origin"]
    local has_origin = false
    
    -- Check Origin header existence once
    for k, _ in pairs(headers) do
        if k:lower() == "origin" then
            has_origin = true
            break
        end
    end

    -- Create context with optimized structure
    local cors_ctx = {
        remote_addr = remote_addr,
        request_id = request_id,
        origin = origin,
        is_cors = has_origin,
        is_preflight = is_options,
        path = path,
        method = method,
        headers = headers,
        config = config.get_route_config(path, method),
        log_context = string.format(
            "client=%s request_id=%s method=%s uri=%s",
            remote_addr,
            request_id,
            method,
            path
        ),
        validation_failed = false
    }
    
    -- Check credentials only if needed
    cors_ctx.has_credentials = has_origin and check_credentials(cors_ctx) or false
    
    if has_origin then
        ngx.log(ngx.DEBUG, string.format("[cors] Created CORS context: %s", cjson.encode(cors_ctx)))
    end
    
    return cors_ctx
end

local function handle_access()
    ngx.log(ngx.DEBUG, "[cors] Access phase started")
    local cors_ctx = get_cors_context()
    ngx.ctx.cors = cors_ctx
    
    -- Validate if it's cors request
    if not cors_ctx.is_cors then
        ngx.log(ngx.DEBUG, string.format("[cors] Not a CORS request - skipping. %s", cors_ctx.log_context))
        return true
    end
    
    -- Validate origin for all CORS requests
    if not validate_origin(cors_ctx) then
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return false
    end
    
    -- Handle preflight requests
    if cors_ctx.is_preflight then
        ngx.log(ngx.DEBUG, string.format("[cors] Processing preflight request. %s", cors_ctx.log_context))
        
        -- Validate preflight method
        local valid_method, err_msg, details = validators.validate_preflight_method(cors_ctx)
        if not valid_method then
            set_error_response(cors_ctx, ngx.HTTP_FORBIDDEN, err_msg, details)
            ngx.exit(ngx.HTTP_FORBIDDEN)
            return false
        end
        
        -- Validate preflight headers
        local valid_headers, err_msg, details = validators.validate_preflight_headers(cors_ctx)
        if not valid_headers then
            set_error_response(cors_ctx, ngx.HTTP_FORBIDDEN, err_msg, details)
            ngx.exit(ngx.HTTP_FORBIDDEN)
            return false
        end
        
        ngx.ctx.skip_response_body = true
        ngx.status = ngx.HTTP_NO_CONTENT
    else
        -- Handle actual CORS requests
        ngx.log(ngx.DEBUG, string.format("[cors] Processing CORS request. %s", cors_ctx.log_context))
        
        -- Validate request method
        local valid_method, err_msg, details = validators.validate_request_method(cors_ctx)
        if not valid_method then
            set_error_response(cors_ctx, ngx.HTTP_FORBIDDEN, err_msg, details)
            ngx.exit(ngx.HTTP_FORBIDDEN)
            return false
        end
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Access phase completed successfully. %s", cors_ctx.log_context))
    return true
end

local function handle_header_filter()
    ngx.log(ngx.DEBUG, "[cors] Header filter started")
    local cors_ctx = ngx.ctx.cors
    
    -- Add security headers for ALL requests
    ngx.header["X-Content-Type-Options"] = "nosniff"
    ngx.header["X-Frame-Options"] = "DENY"
    ngx.header["X-XSS-Protection"] = "1; mode=block"
    
    if not cors_ctx or not cors_ctx.is_cors then
        ngx.log(ngx.DEBUG, string.format("[cors] Not a CORS request - skipping CORS headers. %s", 
            cors_ctx and cors_ctx.log_context or ""))
        return true
    end
    
    -- Handle failed validations
    if cors_ctx.validation_failed then
        ngx.log(ngx.DEBUG, string.format("[cors] Validation failed - setting error response. %s", cors_ctx.log_context))
        ngx.status = ngx.HTTP_FORBIDDEN
        ngx.header["Content-Type"] = "text/plain"
        ngx.header["Content-Length"] = 0
        
        -- Clear any existing CORS headers
        for k, _ in pairs(ngx.header) do
            if k:lower():find("^access%-control%-", 1, true) then
                ngx.header[k] = nil
            end
        end
        ngx.header["Vary"] = nil
        return true
    end
    
    -- Set appropriate CORS headers based on request type
    if cors_ctx.is_preflight then
        handle_preflight_response(cors_ctx)
    else
        handle_cors_response(cors_ctx)
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Header filter completed. %s", cors_ctx.log_context))
    return true
end

local function handle_log()
    ngx.log(ngx.DEBUG, "[cors] Log phase started")
    local cors_ctx = ngx.ctx.cors
    
    if cors_ctx then
        if cors_ctx.validation_failed then
            ngx.log(ngx.WARN, string.format("[cors] Request completed with validation failure. origin=%s is_preflight=%s error=%s. %s",
                cors_ctx.origin or "none",
                tostring(cors_ctx.is_preflight),
                cors_ctx.error_message or "unknown",
                cors_ctx.log_context
            ))
        else
            ngx.log(ngx.INFO, string.format("[cors] Request completed successfully. origin=%s is_preflight=%s has_credentials=%s. %s",
                cors_ctx.origin or "none",
                tostring(cors_ctx.is_preflight),
                tostring(cors_ctx.has_credentials),
                cors_ctx.log_context
            ))
        end
    end

    ngx.log(ngx.DEBUG, "[cors] Log phase completed")
    return true
end

return {
    handle_access = handle_access,
    handle_header_filter = handle_header_filter,
    handle_log = handle_log
} 
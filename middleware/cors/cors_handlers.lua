local cjson = require "cjson"
local config = require "middleware.cors.cors_config"
local validators = require "middleware.cors.cors_validators"
local utils = require "middleware.cors.cors_utils"
local ngx = ngx

-- Helper function to set error response
local function set_error_response(cors_ctx, status, err_msg, details)
    cors_ctx.validation_failed = true
    cors_ctx.error_message = validators.format_cors_error(err_msg, details)
    ngx.status = status
    ngx.ctx.skip_response_body = true
    ngx.log(ngx.WARN, string.format("[cors] Validation failed: %s. %s", err_msg, cors_ctx.log_context))
    ngx.log(ngx.ERR, string.format("[cors] %s", cors_ctx.error_message))
end

local function check_credentials(cors_ctx)
    local has_credentials = false
    
    -- Check for Cookie header (credentials)
    if cors_ctx.headers["Cookie"] then
        has_credentials = true
        ngx.log(ngx.DEBUG, string.format("[cors] Request contains Cookie credentials. %s", cors_ctx.log_context))
    end
    
    -- Check for Authorization header (HTTP authentication)
    if cors_ctx.headers["Authorization"] then
        has_credentials = true
        ngx.log(ngx.DEBUG, string.format("[cors] Request contains Authorization credentials. %s", cors_ctx.log_context))
    end
    
    -- Check for client certificates
    if ngx.var.ssl_client_verify == "SUCCESS" then
        has_credentials = true
        ngx.log(ngx.DEBUG, string.format("[cors] Request contains client certificate credentials. %s", cors_ctx.log_context))
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

local function validate_preflight_method(cors_ctx)
    local request_method = cors_ctx.headers["Access-Control-Request-Method"]
    
    if not request_method then
        set_error_response(cors_ctx, ngx.HTTP_FORBIDDEN, 
            "Missing Access-Control-Request-Method",
            "Preflight request requires Access-Control-Request-Method header")
        return false
    end
    
    request_method = request_method:upper()
    ngx.log(ngx.DEBUG, string.format("[cors] Preflight method validation started: %s. %s", 
        request_method, cors_ctx.log_context))
    
    local method_allowed = false
    for _, allowed_method in ipairs(cors_ctx.config.allow_methods) do
        if request_method == allowed_method:upper() then
            method_allowed = true
            break
        end
    end
    
    if not method_allowed then
        set_error_response(cors_ctx, ngx.HTTP_FORBIDDEN, 
            "Method not allowed in preflight", request_method)
        return false
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Preflight method validation successful. %s", cors_ctx.log_context))
    return true
end

local function validate_preflight_headers(cors_ctx)
    local request_headers = cors_ctx.headers["Access-Control-Request-Headers"]
    
    if not request_headers then
        ngx.log(ngx.DEBUG, string.format("[cors] No custom headers requested in preflight. %s", cors_ctx.log_context))
        return true
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Preflight headers validation started: %s. %s", 
        request_headers, cors_ctx.log_context))
    
    for header in request_headers:gmatch("([^,%s]+)") do
        local lower_header = header:lower()
        if not (cors_ctx.config.common_headers[lower_header] or cors_ctx.config.allow_headers[lower_header]) then
            set_error_response(cors_ctx, ngx.HTTP_FORBIDDEN, 
                "Header not allowed in preflight", header)
            return false
        end
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Preflight headers validation successful. %s", cors_ctx.log_context))
    return true
end

local function validate_request_method(cors_ctx)
    local method = cors_ctx.method:upper()
    ngx.log(ngx.DEBUG, string.format("[cors] Request method validation started: %s. %s", 
        method, cors_ctx.log_context))
    
    local method_allowed = false
    for _, allowed_method in ipairs(cors_ctx.config.allow_methods) do
        if method == allowed_method:upper() then
            method_allowed = true
            break
        end
    end
    
    if not method_allowed then
        set_error_response(cors_ctx, ngx.HTTP_FORBIDDEN, 
            "Method not allowed", method)
        return false
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Request method validation successful. %s", cors_ctx.log_context))
    return true
end

local function handle_preflight_response(cors_ctx)
    ngx.log(ngx.DEBUG, string.format("[cors] Setting preflight response headers. %s", cors_ctx.log_context))
    
    -- Set required CORS headers
    ngx.header["Access-Control-Allow-Origin"] = validators.sanitize_header(cors_ctx.origin)
    ngx.header["Access-Control-Allow-Methods"] = cors_ctx.config.cache.allow_methods_str
    ngx.header["Access-Control-Allow-Headers"] = cors_ctx.config.cache.allow_headers_str
    ngx.header["Access-Control-Max-Age"] = cors_ctx.config.max_age
    ngx.header["Vary"] = "Origin, Access-Control-Request-Method, Access-Control-Request-Headers"
    
    -- Set credentials header if credentials are allowed
    if cors_ctx.has_credentials and cors_ctx.config.allow_credentials then
        ngx.header["Access-Control-Allow-Credentials"] = "true"
    end
    
    -- Set security headers
    ngx.header["X-Content-Type-Options"] = "nosniff"
    ngx.header["X-Frame-Options"] = "DENY"
    ngx.header["X-XSS-Protection"] = "1; mode=block"
    
    ngx.status = ngx.HTTP_NO_CONTENT
    ngx.header["Content-Length"] = 0
    ngx.ctx.skip_response_body = true
end

local function handle_cors_response(cors_ctx)
    ngx.log(ngx.DEBUG, string.format("[cors] Setting CORS response headers. %s", cors_ctx.log_context))
    
    -- Set required CORS headers
    ngx.header["Access-Control-Allow-Origin"] = validators.sanitize_header(cors_ctx.origin)
    ngx.header["Vary"] = "Origin"
    
    -- Set exposed headers if configured
    if cors_ctx.config.cache.expose_headers_str then
        ngx.header["Access-Control-Expose-Headers"] = cors_ctx.config.cache.expose_headers_str
    end
    
    -- Set credentials header if credentials are allowed
    if cors_ctx.has_credentials and cors_ctx.config.allow_credentials then
        ngx.header["Access-Control-Allow-Credentials"] = "true"
    end
    
    -- Set security headers
    ngx.header["X-Content-Type-Options"] = "nosniff"
    ngx.header["X-Frame-Options"] = "DENY"
    ngx.header["X-XSS-Protection"] = "1; mode=block"
end

local function get_cors_context()
    local headers = ngx.req.get_headers()
    local origin = headers["Origin"]
    local path = ngx.var.request_uri
    local method = ngx.req.get_method():upper()
    local request_id = ngx.ctx.request_id or "none"
    local remote_addr = ngx.var.remote_addr
    
    local log_context = string.format(
        "client=%s request_id=%s method=%s uri=%s",
        remote_addr,
        request_id, 
        method,
        path
    )

    -- Check if Origin header exists in the raw headers
    local has_origin_header = false
    for k, _ in pairs(headers) do
        if k:lower() == "origin" then
            has_origin_header = true
            break
        end
    end

    local cors_ctx = {
        remote_addr = remote_addr,
        request_id = request_id,
        origin = origin,
        -- Treat as CORS request if Origin header exists (even if empty)
        is_cors = has_origin_header,
        is_preflight = method == "OPTIONS",
        path = path,
        method = method,
        headers = headers,
        config = config.get_route_config(path, method),
        log_context = log_context,
        validation_failed = false,
        has_credentials = false
    }
    
    -- Check for credentials
    cors_ctx.has_credentials = check_credentials(cors_ctx)
    
    ngx.log(ngx.DEBUG, string.format("[cors] Created CORS context: %s", cjson.encode(cors_ctx)))
    return cors_ctx
end

local function handle_access()
    ngx.log(ngx.DEBUG, "[cors] Access phase started")
    local cors_ctx = get_cors_context()
    ngx.ctx.cors = cors_ctx
    
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
        
        if not validate_preflight_method(cors_ctx) or not validate_preflight_headers(cors_ctx) then
            ngx.exit(ngx.HTTP_FORBIDDEN)
            return false
        end
        
        ngx.ctx.skip_response_body = true
        ngx.status = ngx.HTTP_NO_CONTENT
    else
        -- Handle actual CORS requests
        ngx.log(ngx.DEBUG, string.format("[cors] Processing CORS request. %s", cors_ctx.log_context))
        
        if not validate_request_method(cors_ctx) then
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
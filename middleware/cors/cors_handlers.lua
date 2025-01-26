local cjson = require "cjson"
local config = require "middleware.cors.cors_config"
local validators = require "middleware.cors.cors_validators"
local utils = require "middleware.cors.cors_utils"
local ngx = ngx

local function get_cors_context()
    local headers = ngx.req.get_headers()
    local origin = headers["Origin"]
    local path = ngx.var.request_uri
    local method = ngx.req.get_method():upper()
    local request_id = ngx.ctx.request_id or "none"
    local remote_addr = ngx.var.remote_addr
    
    -- Create log context string once
    local log_context = string.format(
        "client=%s request_id=%s method=%s uri=%s",
        remote_addr,
        request_id, 
        method,
        path
    )

    -- Return CORS context with all needed info
    local cors_ctx = {
        remote_addr = remote_addr,
        request_id = request_id,
        origin = origin,
        is_cors = origin ~= nil,
        is_preflight = method == "OPTIONS",
        path = path,
        method = method,
        headers = headers,
        config = config.get_route_config(path, method),
        log_context = log_context
    }
    ngx.log(ngx.DEBUG, string.format("[cors] cors_ctx: %s", cjson.encode(cors_ctx)))
    ngx.log(ngx.DEBUG, string.format("[cors] cors_ctx config: %s", cjson.encode(cors_ctx.config)))
    return cors_ctx
end

local function handle_preflight(cors_ctx)
    ngx.log(ngx.DEBUG, string.format("[cors] Preflight handling started. %s", cors_ctx.log_context))
    
    -- Validate Access-Control-Request-Method
    local request_method = cors_ctx.headers["Access-Control-Request-Method"]
    if not request_method then
        local err = validators.format_cors_error(
            "Missing Access-Control-Request-Method",
            "Preflight request requires Access-Control-Request-Method header"
        )
        ngx.log(ngx.WARN, string.format("[cors] Preflight validation failed - missing method. %s", cors_ctx.log_context))
        ngx.log(ngx.ERR, string.format("[cors] %s", err))
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Preflight method validation started: %s. %s", request_method, cors_ctx.log_context))
    
    if not table.concat(cors_ctx.config.allow_methods, ","):find(request_method, 1, true) then
        local err = validators.format_cors_error("Method not allowed in preflight", request_method)
        ngx.log(ngx.WARN, string.format("[cors] Preflight method validation failed: %s. %s", request_method, cors_ctx.log_context))
        ngx.log(ngx.ERR, string.format("[cors] %s", err))
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return
    end
    
    -- Validate Access-Control-Request-Headers
    local request_headers = cors_ctx.headers["Access-Control-Request-Headers"]
    if request_headers then
        ngx.log(ngx.DEBUG, string.format("[cors] Preflight headers validation started: %s. %s", request_headers, cors_ctx.log_context))
        
        for header in request_headers:gmatch("([^,%s]+)") do
            local lower_header = header:lower()
            if not (cors_ctx.config.common_headers[lower_header] or cors_ctx.config.allow_headers[lower_header]) then
                local err = validators.format_cors_error("Header not allowed in preflight", header)
                ngx.log(ngx.WARN, string.format("[cors] Preflight headers validation failed: %s. %s", header, cors_ctx.log_context))
                ngx.log(ngx.ERR, string.format("[cors] %s", err))
                ngx.exit(ngx.HTTP_FORBIDDEN)
                return
            end
        end
        ngx.log(ngx.DEBUG, string.format("[cors] Preflight headers validation completed. %s", cors_ctx.log_context))
    end
    
    -- Set preflight response headers using route-specific cached values
    ngx.log(ngx.DEBUG, string.format("[cors] Preflight response headers setup started. methods=%s headers=%s max_age=%s. %s", 
        cors_ctx.config.cache.methods_str, cors_ctx.config.cache.headers_str, cors_ctx.config.max_age, cors_ctx.log_context))
    
    ngx.header["Access-Control-Allow-Methods"] = cors_ctx.config.cache.methods_str
    ngx.header["Access-Control-Allow-Headers"] = cors_ctx.config.cache.headers_str
    ngx.header["Access-Control-Max-Age"] = cors_ctx.config.max_age
    
    ngx.log(ngx.INFO, string.format("[cors] Preflight handling completed successfully. %s", cors_ctx.log_context))
    ngx.status = ngx.HTTP_NO_CONTENT
    ngx.exit(ngx.HTTP_NO_CONTENT)
end

local function handle_access()
    local cors_ctx = get_cors_context()
    ngx.ctx.cors = cors_ctx
    
    ngx.log(ngx.DEBUG, string.format("[cors] Access phase started. %s", cors_ctx.log_context))
    
    -- Early return if not a CORS request
    if not cors_ctx.is_cors then
        ngx.log(ngx.DEBUG, string.format("[cors] Access phase completed - non-CORS request. %s", cors_ctx.log_context))
        return true
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] CORS request validation started. origin=%s method=%s is_preflight=%s. %s", 
        cors_ctx.origin, cors_ctx.method, cors_ctx.is_preflight, cors_ctx.log_context))
    
    -- Validate origin for all CORS requests
    if not validators.is_origin_allowed(cors_ctx) then
        ngx.log(ngx.WARN, string.format("[cors] Origin validation failed: %s. %s", cors_ctx.origin, cors_ctx.log_context))
        ngx.log(ngx.ERR, validators.format_cors_error("Origin not allowed", cors_ctx.origin))
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return false
    end
    
    -- Handle preflight
    if cors_ctx.is_preflight then
        handle_preflight(cors_ctx)
        return false
    end
    
    -- Validate method for non-preflight requests
    if not table.concat(cors_ctx.config.allow_methods, ","):find(cors_ctx.method, 1, true) then
        ngx.log(ngx.WARN, string.format("[cors] Method validation failed: %s. %s", cors_ctx.method, cors_ctx.log_context))
        local err = validators.format_cors_error("Method not allowed", cors_ctx.method)
        ngx.log(ngx.ERR, string.format("[cors] %s", err))
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return false
    end
    
    -- Validate headers
    for header_name in pairs(cors_ctx.headers) do
        local lower_header = header_name:lower()
        if not (cors_ctx.config.common_headers[lower_header] or cors_ctx.config.allow_headers[lower_header]) then
            ngx.log(ngx.WARN, string.format("[cors] Headers validation failed: %s. %s", header_name, cors_ctx.log_context))
            local err = validators.format_cors_error("Header not allowed", header_name)
            ngx.log(ngx.ERR, string.format("[cors] %s", err))
            ngx.exit(ngx.HTTP_FORBIDDEN)
            return false
        end
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Access phase completed successfully. %s", cors_ctx.log_context))
    return true
end

local function handle_header_filter()
    local cors_ctx = ngx.ctx.cors
    
    if not cors_ctx or not cors_ctx.is_cors then
        ngx.log(ngx.DEBUG, string.format("[cors] Header filter skipped - non-CORS request. %s", cors_ctx and cors_ctx.log_context or ""))
        return true
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Header filter started. origin=%s. %s", cors_ctx.origin, cors_ctx.log_context))
    
    local origin = validators.sanitize_header(cors_ctx.origin)

    -- Only set CORS headers if the origin is allowed
    if validators.is_origin_allowed(cors_ctx) then
        -- Set CORS response headers using route-specific cached values
        ngx.header["Access-Control-Allow-Origin"] = origin
        
        if cors_ctx.config.allow_credentials then
            ngx.header["Access-Control-Allow-Credentials"] = "true"
        end
        
        if cors_ctx.config.cache.expose_headers_str then
            ngx.header["Access-Control-Expose-Headers"] = cors_ctx.config.cache.expose_headers_str
        end
        
        -- Set Vary header
        local vary = "Origin, Access-Control-Request-Method, Access-Control-Request-Headers"
        if ngx.header["Vary"] then
            ngx.header["Vary"] = ngx.header["Vary"] .. ", " .. vary
        else
            ngx.header["Vary"] = vary
        end
        
        ngx.log(ngx.DEBUG, string.format("[cors] Header filter completed. vary=%s. %s", ngx.header["Vary"], cors_ctx.log_context))
        return true
    else
        ngx.log(ngx.WARN, string.format("[cors] Origin not allowed in header filter: %s. %s", origin, cors_ctx.log_context))
        ngx.log(ngx.ERR, validators.format_cors_error("Origin not allowed", origin))
        ngx.status = ngx.HTTP_FORBIDDEN
        ngx.header.content_type = "text/plain"
        ngx.header.content_length = 0
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return false
    end
end

local function handle_log()
    local cors_ctx = ngx.ctx.cors
    
    if cors_ctx then
        ngx.log(ngx.INFO, string.format("[cors] Request processing completed. origin=%s is_preflight=%s. %s",
            cors_ctx.origin or "none",
            tostring(cors_ctx.is_preflight),
            cors_ctx.log_context
        ))
    end
    
    return true
end

return {
    handle_access = handle_access,
    handle_header_filter = handle_header_filter,
    handle_log = handle_log
} 
local config = require "modules.middleware.cors.config"
local validators = require "modules.middleware.cors.validators"
local utils = require "modules.middleware.cors.utils"
local ngx = ngx

local function get_request_context()
    return string.format(
        "client=%s request_id=%s method=%s uri=%s",
        ngx.var.remote_addr,
        ngx.var.request_id or "none",
        ngx.req.get_method(),
        ngx.var.request_uri
    )
end

local function handle_preflight()
    local ctx = get_request_context()
    ngx.log(ngx.DEBUG, string.format("[cors] Preflight handling started. %s", ctx))
    
    local headers = ngx.req.get_headers()
    
    -- Validate Access-Control-Request-Method
    local request_method = headers["Access-Control-Request-Method"]
    if not request_method then
        local err = validators.format_cors_error(
            "Missing Access-Control-Request-Method",
            "Preflight request requires Access-Control-Request-Method header"
        )
        ngx.log(ngx.WARN, string.format("[cors] Preflight validation failed - missing method. %s", ctx))
        ngx.log(ngx.ERR, string.format("[cors] %s", err))
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Preflight method validation started: %s. %s", request_method, ctx))
    
    if not table.concat(config.current.allow_methods, ","):find(request_method, 1, true) then
        local err = validators.format_cors_error("Method not allowed in preflight", request_method)
        ngx.log(ngx.WARN, string.format("[cors] Preflight method validation failed: %s. %s", request_method, ctx))
        ngx.log(ngx.ERR, string.format("[cors] %s", err))
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return
    end
    
    -- Validate Access-Control-Request-Headers
    local request_headers = headers["Access-Control-Request-Headers"]
    if request_headers then
        ngx.log(ngx.DEBUG, string.format("[cors] Preflight headers validation started: %s. %s", request_headers, ctx))
        
        for header in request_headers:gmatch("([^,%s]+)") do
            local lower_header = header:lower()
            if not (config.cache.allowed_headers_map[lower_header] or config.common_headers_map[lower_header]) then
                local err = validators.format_cors_error("Header not allowed in preflight", header)
                ngx.log(ngx.WARN, string.format("[cors] Preflight headers validation failed: %s. %s", header, ctx))
                ngx.log(ngx.ERR, string.format("[cors] %s", err))
                ngx.exit(ngx.HTTP_FORBIDDEN)
                return
            end
        end
        ngx.log(ngx.DEBUG, string.format("[cors] Preflight headers validation completed. %s", ctx))
    end
    
    -- Set preflight response headers using cached values
    ngx.log(ngx.DEBUG, string.format("[cors] Preflight response headers setup started. methods=%s headers=%s max_age=%s. %s", 
        config.cache.methods_str, config.cache.headers_str, config.current.max_age, ctx))
    
    ngx.header["Access-Control-Allow-Methods"] = config.cache.methods_str
    ngx.header["Access-Control-Allow-Headers"] = config.cache.headers_str
    ngx.header["Access-Control-Max-Age"] = config.current.max_age
    
    ngx.log(ngx.INFO, string.format("[cors] Preflight handling completed successfully. %s", ctx))
    ngx.status = ngx.HTTP_NO_CONTENT
    ngx.exit(ngx.HTTP_NO_CONTENT)
end

local function handle_access()
    local ctx = get_request_context()
    ngx.log(ngx.DEBUG, string.format("[cors] Access phase started. %s", ctx))
    
    local headers = ngx.req.get_headers()
    local origin = headers["Origin"]
    local method = ngx.req.get_method():upper()
    
    -- Store CORS context
    local cors_ctx = {
        origin = origin,
        is_cors = origin ~= nil,
        is_preflight = method == "OPTIONS"
    }
    ngx.ctx.cors = cors_ctx
    
    -- Early return if not a CORS request
    if not origin then
        ngx.log(ngx.DEBUG, string.format("[cors] Access phase completed - non-CORS request. %s", ctx))
        return true
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] CORS request validation started. origin=%s method=%s is_preflight=%s. %s", 
        origin, method, cors_ctx.is_preflight, ctx))
    
    -- Validate origin for all CORS requests
    if not validators.is_origin_allowed(origin, config.current.allow_origins) then
        ngx.log(ngx.WARN, string.format("[cors] Origin validation failed: %s. %s", origin, ctx))
        ngx.log(ngx.ERR, validators.format_cors_error("Origin not allowed", origin))
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return false
    end
    
    -- Handle preflight
    if method == "OPTIONS" then
        handle_preflight()
        return false
    end
    
    -- Validate method for non-preflight requests
    if not table.concat(config.current.allow_methods, ","):find(method, 1, true) then
        ngx.log(ngx.WARN, string.format("[cors] Method validation failed: %s. %s", method, ctx))
        local err = validators.format_cors_error("Method not allowed", method)
        ngx.log(ngx.ERR, string.format("[cors] %s", err))
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return false
    end
    
    -- Validate headers
    for header_name in pairs(headers) do
        local lower_header = header_name:lower()
        if not (config.cache.allowed_headers_map[lower_header] or config.common_headers_map[lower_header]) then
            ngx.log(ngx.WARN, string.format("[cors] Headers validation failed: %s. %s", header_name, ctx))
            local err = validators.format_cors_error("Header not allowed", header_name)
            ngx.log(ngx.ERR, string.format("[cors] %s", err))
            ngx.exit(ngx.HTTP_FORBIDDEN)
            return false
        end
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Access phase completed successfully. %s", ctx))
    return true
end

local function handle_header_filter()
    local ctx = get_request_context()
    local cors_ctx = ngx.ctx.cors
    
    if not cors_ctx or not cors_ctx.is_cors then
        ngx.log(ngx.DEBUG, string.format("[cors] Header filter skipped - non-CORS request. %s", ctx))
        return true
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Header filter started. origin=%s. %s", cors_ctx.origin, ctx))
    
    local origin = validators.sanitize_header(cors_ctx.origin)
    
    -- Set CORS response headers using cached values
    ngx.header["Access-Control-Allow-Origin"] = origin
    
    if config.current.allow_credentials then
        ngx.header["Access-Control-Allow-Credentials"] = "true"
    end
    
    if config.cache.expose_headers_str then
        ngx.header["Access-Control-Expose-Headers"] = config.cache.expose_headers_str
    end
    
    -- Set Vary header
    local vary = "Origin, Access-Control-Request-Method, Access-Control-Request-Headers"
    if ngx.header["Vary"] then
        ngx.header["Vary"] = ngx.header["Vary"] .. ", " .. vary
    else
        ngx.header["Vary"] = vary
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Header filter completed. vary=%s. %s", ngx.header["Vary"], ctx))
    return true
end

local function handle_log()
    local ctx = get_request_context()
    local cors_ctx = ngx.ctx.cors
    
    if cors_ctx then
        ngx.log(ngx.INFO, string.format("[cors] Request processing completed. origin=%s is_preflight=%s. %s",
            cors_ctx.origin or "none",
            tostring(cors_ctx.is_preflight),
            ctx
        ))
    end
    
    return true
end

return {
    handle_access = handle_access,
    handle_header_filter = handle_header_filter,
    handle_log = handle_log
} 
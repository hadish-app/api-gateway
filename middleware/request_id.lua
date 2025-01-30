local ngx = ngx
local uuid = require "resty.jit-uuid"
local middleware_chain = require "modules.core.middleware_chain"

-- Constants for ctx keys to avoid typos and make refactoring easier
local CTX_KEYS = {
    REQUEST_ID = "request_id",
    HEADER_NAME = "request_id_header_name",
    STATE = "request_id_state"  -- Track middleware state across phases
}

local config = {
    header_name = "X-Request-ID"
}

-- Initialize UUID generator
local function init_worker()
    -- Seed the UUID generator with worker-specific seed
    local seed = ngx.time() + ngx.worker.pid()
    uuid.seed(seed)
    ngx.log(ngx.DEBUG, "[Request ID] UUID generator initialized with seed: ", seed)
end

-- Re-seed for each request to ensure uniqueness
local function reseed_uuid()
    -- Force a new seed for each request using high-precision time
    local seed = ngx.now() * 1000000 + ngx.worker.pid()
    uuid.seed(seed)
    -- Clear any cached values
    uuid.generate_v4()  -- Discard first value after reseed
end

-- Shared utility functions
local _M = {}

function _M.generate_request_id()
    local id = uuid.generate_v4()
    ngx.log(ngx.DEBUG, "[Request ID] Generated new UUID: ", id)
    return id
end

function _M.get_request_id()
    return ngx.ctx[CTX_KEYS.REQUEST_ID]
end

function _M.set_request_id(id)
    ngx.ctx[CTX_KEYS.REQUEST_ID] = id
    -- Store state to indicate request ID was set
    ngx.ctx[CTX_KEYS.STATE] = true
    -- Store header name for consistency across phases
    ngx.ctx[CTX_KEYS.HEADER_NAME] = config.header_name
end

function _M.is_valid_uuid(str)
    -- Simple UUID pattern: 8-4-4-4-12 hex digits
    local pattern = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
    return type(str) == "string" and string.match(str, pattern) ~= nil
end

-- Access phase handler
local function handle_access(self)
    ngx.log(ngx.DEBUG, "[Request ID] [access phase] Starting access phase")
    
    -- Always reseed at the start of each request
    reseed_uuid()
    
    -- Check for incoming request ID
    local headers = ngx.req.get_headers()
    local incoming_id = headers[config.header_name]
    ngx.log(ngx.DEBUG, "[Request ID] [access phase] Request ID from header: ", incoming_id)
    
    local request_id
    if incoming_id and _M.is_valid_uuid(incoming_id) then
        -- Use valid incoming request ID
        request_id = incoming_id
        ngx.log(ngx.DEBUG, "[Request ID] [access phase] Using existing request ID: ", request_id)
    else
        -- Generate new request ID if none exists or invalid
        if incoming_id then
            ngx.log(ngx.WARN, "[Request ID] Invalid request ID format received: ", incoming_id)
        end
        request_id = _M.generate_request_id()
        ngx.log(ngx.DEBUG, "[Request ID] [access phase] Generated new request ID after invalid input: ", request_id)
    end
    
    -- Store in context for other phases
    _M.set_request_id(request_id)
    ngx.log(ngx.DEBUG, "[Request ID] [access phase] Stored request ID in context")
    
    ngx.log(ngx.DEBUG, "[Request ID] [access phase] access phase completed")
    return true
end

-- Header filter phase handler
local function handle_header_filter(self)
    ngx.log(ngx.DEBUG, "[Request ID] [header filter phase] Starting header filter phase")

    local request_id = _M.get_request_id()
    if not request_id then
        ngx.log(ngx.ERR, "[Request ID] [header filter phase] Critical error - No request ID in context. This should never happen!")
        -- Log additional debug information
        ngx.log(ngx.ERR, string.format(
            "Debug info - Client: %s, Method: %s, URI: %s, Headers: %s",
            ngx.var.remote_addr,
            ngx.req.get_method(),
            ngx.var.request_uri,
            require("cjson").encode(ngx.req.get_headers())
        ))
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        return false  
    end

    local existing_header = ngx.header[config.header_name]
    if existing_header then
        -- Validate existing header format
        if not _M.is_valid_uuid(existing_header) then
            ngx.log(ngx.WARN, "[Request ID] [header filter phase] Invalid UUID format in response header: ", existing_header)
            ngx.status = ngx.HTTP_BAD_REQUEST
            ngx.say("Invalid Request ID Format")
            return false
        end

        if existing_header ~= request_id then
            ngx.log(ngx.WARN, "[Request ID] [header filter phase] Detected header tampering attempt. ",
                "Context ID: ", request_id,
                " Header ID: ", existing_header,
                " Client IP: ", ngx.var.remote_addr,
                " User Agent: ", ngx.var.http_user_agent,
                " Request Method: ", ngx.req.get_method(),
                " URI: ", ngx.var.request_uri,
                " Host: ", ngx.var.host)
            ngx.status = ngx.HTTP_BAD_REQUEST
            return false
        end
        -- Header already set correctly, no need to set it again
        ngx.log(ngx.DEBUG, "[Request ID] [header filter phase] Header already set correctly")
    else
        -- Set the header if it doesn't exist
        ngx.log(ngx.DEBUG, "[Request ID] [header filter phase] Setting response header X-Request-ID: ", request_id)
        ngx.header["X-Request-ID"] = request_id
        ngx.log(ngx.DEBUG, "[Request ID] [header filter phase] Header set: ", ngx.header["X-Request-ID"])
    end
    
    ngx.log(ngx.DEBUG, "[Request ID] [header filter phase] header filter phase completed")
    return true
end

-- Log phase handler
local function handle_log(self)
    ngx.log(ngx.DEBUG, "[Request ID] [log phase] Starting log phase")
    
    local request_id = _M.get_request_id()
    if not request_id then
        ngx.log(ngx.ERR, "[Request ID] [header filter phase] Security alert - No request ID in context. This should never happen!")
        -- Log additional debug information
        ngx.log(ngx.ERR, string.format(
            "Debug info - Client: %s, Method: %s, URI: %s, Headers: %s",
            ngx.var.remote_addr,
            ngx.req.get_method(),
            ngx.var.request_uri,
            require("cjson").encode(ngx.req.get_headers())
        ))
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        return false  
    end

    local existing_header = ngx.req.get_headers()[config.header_name]
    if existing_header then
        -- Validate existing header format
        if not _M.is_valid_uuid(existing_header) then
            ngx.log(ngx.WARN, "[Request ID] [log phase] Security alert - Invalid UUID format in response header: ", existing_header)
            ngx.status = ngx.HTTP_BAD_REQUEST
            ngx.say("Invalid Request ID Format")
            return false
        end

        if existing_header ~= request_id then
            ngx.log(ngx.WARN, "[Request ID] [log phase] Security alert - Detected header tampering attempt. ",
                "Context ID: ", request_id,
                " Header ID: ", existing_header,
                " Client IP: ", ngx.var.remote_addr,
                " User Agent: ", ngx.var.http_user_agent,
                " Request Method: ", ngx.req.get_method(),
                " URI: ", ngx.var.request_uri,
                " Host: ", ngx.var.host)
            ngx.status = ngx.HTTP_BAD_REQUEST
            return false
        end
        -- Header already set correctly, no need to set it again
        ngx.log(ngx.DEBUG, "[Request ID] [log phase] Header already set correctly")
    end

    ngx.log(ngx.INFO, "[Request ID] [log phase] Request completed with ID: ", request_id, " client: ", ngx.var.remote_addr, ", server: ", ngx.var.server_name, ", request: ", ngx.var.request_uri)

    return true
end

-- Access phase middleware
local access_middleware = {
    name = "request_id_access",
    routes = {},    -- Global middleware
    enabled = true,
    phase = "access",
    config = config,
    handle = handle_access,
    get_request_id = _M.get_request_id
}

-- Header filter phase middleware
local header_filter_middleware = {
    name = "request_id_header_filter",
    routes = {},    -- Global middleware
    enabled = true,
    phase = "header_filter",
    config = config,
    handle = handle_header_filter,
    get_request_id = _M.get_request_id
}

-- Log phase middleware
local log_middleware = {
    name = "request_id_log",
    routes = {},    -- Global middleware
    enabled = true,
    phase = "log",
    config = config,
    handle = handle_log,
    get_request_id = _M.get_request_id
}

return {
    access = access_middleware,
    header_filter = header_filter_middleware,
    log = log_middleware,
    _M = _M -- Export utility functions for testing and reuse
} 
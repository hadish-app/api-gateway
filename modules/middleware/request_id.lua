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
    ngx.log(ngx.DEBUG, "Request ID middleware: UUID generator initialized with seed: ", seed)
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
    ngx.log(ngx.DEBUG, "Request ID middleware: Generated new UUID: ", id)
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
    ngx.log(ngx.DEBUG, "Request ID middleware: Starting access phase")
    
    -- Always reseed at the start of each request
    reseed_uuid()
    
    -- Check for incoming request ID
    local headers = ngx.req.get_headers()
    local incoming_id = headers["X-Request-ID"]
    ngx.log(ngx.DEBUG, "Request ID middleware: Request ID from header: ", incoming_id)
    
    local request_id
    if incoming_id and _M.is_valid_uuid(incoming_id) then
        -- Use valid incoming request ID
        request_id = incoming_id
        ngx.log(ngx.DEBUG, "Request ID middleware: Using existing request ID: ", request_id)
    else
        -- Generate new request ID if none exists or invalid
        if incoming_id then
            ngx.log(ngx.WARN, "Request ID middleware: Invalid request ID format received: ", incoming_id)
        end
        request_id = _M.generate_request_id()
        ngx.log(ngx.DEBUG, "Request ID middleware: Generated new request ID after invalid input: ", request_id)
    end
    
    -- Store in context for other phases
    _M.set_request_id(request_id)
    ngx.log(ngx.DEBUG, "Request ID middleware: Stored request ID in context")
    
    return true
end

-- Header filter phase handler
local function handle_header_filter(self)
    ngx.log(ngx.DEBUG, "Request ID middleware: Starting header filter phase")
    
    -- Get request ID from context
    local request_id = ngx.ctx.request_id
    if not request_id then
        ngx.log(ngx.WARN, "Request ID middleware: No request ID found in context")
        return true
    end
    
    -- Check for header tampering
    local existing_header = ngx.header["X-Request-ID"]
    if existing_header then
        if existing_header ~= request_id then
            ngx.log(ngx.WARN, "Request ID middleware: Detected header tampering attempt. ",
                "Context ID: ", request_id,
                " Header ID: ", existing_header,
                " Client IP: ", ngx.var.remote_addr,
                " User Agent: ", ngx.var.http_user_agent,
                " Request Method: ", ngx.req.get_method(),
                " URI: ", ngx.var.request_uri,
                " Host: ", ngx.var.host)
            ngx.status = ngx.HTTP_BAD_REQUEST
            ngx.say("Invalid Request ID")
            return false
        end
        -- Header already set correctly, no need to set it again
    else
        -- Missing header when we expect it to exist
        ngx.log(ngx.DEBUG, "Request ID middleware: Setting response header X-Request-ID in header filter phase. Context ID: ", request_id)
        ngx.header["X-Request-ID"] = request_id
    end
    
    ngx.log(ngx.DEBUG, "Request ID middleware: Set response header X-Request-ID: ", request_id)
    
    return true
end

-- Log phase handler
local function handle_log(self)
    ngx.log(ngx.DEBUG, "Request ID middleware: Starting log phase")
    
    -- Get request ID from context
    local request_id = ngx.ctx.request_id
    if not request_id then
        ngx.log(ngx.WARN, "Request ID middleware: No request ID found in context")
        return true
    end
    
    -- Log request completion
    ngx.log(ngx.INFO, "Request completed with ID: ", request_id)
    
    return true
end

-- Access phase middleware
local access_middleware = {
    name = "request_id_access",
    routes = {},    -- Global middleware
    state = middleware_chain.STATES.ACTIVE,
    phase = "access",
    config = config,
    handle = handle_access,
    get_request_id = _M.get_request_id
}

-- Header filter phase middleware
local header_filter_middleware = {
    name = "request_id_header_filter",
    routes = {},    -- Global middleware
    state = middleware_chain.STATES.ACTIVE,
    phase = "header_filter",
    config = config,
    handle = handle_header_filter,
    get_request_id = _M.get_request_id
}

-- Log phase middleware
local log_middleware = {
    name = "request_id_log",
    routes = {},    -- Global middleware
    state = middleware_chain.STATES.ACTIVE,
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
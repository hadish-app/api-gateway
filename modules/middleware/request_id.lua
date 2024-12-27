local uuid = require "resty.jit-uuid"
local middleware_chain = require "modules.core.middleware_chain"
local logger = require "modules.utils.logger"

local config = {
    header_name = "X-Request-ID",
    context_key = "request_id",
    generate_if_missing = true
}

-- Initialize UUID generator
uuid.seed()
logger.debug("Request ID middleware: UUID generator initialized")

local generate_request_id = function()
    local id = uuid.generate_v4()
    logger.debug("Request ID middleware: Generated new UUID:", id)
    return id
end

local handle_request_id = function(self)
    logger.debug("Request ID middleware: Starting handler")
    
    -- Try to get existing request ID from header
    local headers = ngx.req.get_headers()
    local request_id = headers[self.config.header_name]
    logger.debug("Request ID middleware: Existing header value:", request_id or "nil")
    
    -- Generate new ID if missing and configured to do so
    if not request_id and self.config.generate_if_missing then
        request_id = generate_request_id()
        logger.debug("Request ID middleware: Generated new request ID:", request_id)
    end
    
    if request_id then
        -- Store in nginx ctx for reuse during request
        ngx.ctx[self.config.context_key] = request_id
        logger.debug("Request ID middleware: Stored in context key", self.config.context_key .. ":", request_id)
        
        -- Set response header
        ngx.header[self.config.header_name] = request_id
        logger.debug("Request ID middleware: Set response header", self.config.header_name .. ":", request_id)
    else
        logger.warn("Request ID middleware: No request ID available and generation disabled")
    end
    
    logger.debug("Request ID middleware: Handler completed successfully")
    return true
end

local get_request_id = function(self)
    local id = ngx.ctx[self.config.context_key]
    logger.debug("Request ID middleware: Getting request ID from context:", id or "nil")
    return id
end

local _M = {
    name = "request_id",
    priority = 10,  -- Run very early in the chain
    routes = {},    -- Global middleware
    state = middleware_chain.STATES.ACTIVE,
    
    config = config,
    handle = handle_request_id,
    get_request_id = get_request_id
}

return _M 
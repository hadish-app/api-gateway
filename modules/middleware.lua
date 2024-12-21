local _M = {}

-- Middleware registry
local middleware = {
    -- Request middleware
    rate_limit = require "middleware.rate_limit",
    request_tracking = require "middleware.request_tracking",
    health_check = require "middleware.health_check",
    proxy = require "middleware.proxy",
    ip_ban = require "middleware.ip_ban",
    
    -- Response middleware
    cors = require "middleware.cors",
    security_headers = require "middleware.security_headers",
    metrics = require "middleware.metrics",
    
    -- Error middleware
    error_tracking = require "middleware.error_tracking"
}

-- Create a new context for middleware chain
function _M.new_context()
    return {
        data = {},           -- Shared data between middleware
        response = {},       -- Response data
        error = nil,         -- Error information
        metrics = {},        -- Metrics data
        start_time = ngx.now() -- Request start time
    }
end

-- Run a specific middleware
function _M.run(ctx, name)
    local handler = middleware[name]
    if not handler then
        ngx.log(ngx.ERR, "Middleware not found: ", name)
        return false
    end

    -- Execute the middleware with error handling
    local ok, err = pcall(handler.execute, ctx)
    if not ok then
        ngx.log(ngx.ERR, "Middleware error in ", name, ": ", err)
        return false
    end

    -- Check if middleware wants to stop the chain
    if err == false then
        return false
    end

    return true
end

return _M 
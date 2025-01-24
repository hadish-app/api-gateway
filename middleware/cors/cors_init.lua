local config = require "middleware.cors.cors_config"
local handlers = require "middleware.cors.cors_handlers"

-- Initialize with default config
local _M = {}

function _M.configure(user_config)
    return config.configure(user_config)
end

function _M.update_config(user_config)
    return config.update_config(user_config)
end

-- Create middleware handlers
local access_middleware = {
    name = "cors_access",
    routes = {},    -- Global middleware
    enabled = true,
    phase = "access",
    handle = handlers.handle_access
}

local header_filter_middleware = {
    name = "cors_header_filter",
    routes = {},    -- Global middleware
    enabled = true,
    phase = "header_filter",
    handle = handlers.handle_header_filter
}

local log_middleware = {
    name = "cors_log",
    routes = {},    -- Global middleware
    enabled = true,
    phase = "log",
    handle = handlers.handle_log
}

return {
    access = access_middleware,
    header_filter = header_filter_middleware,
    log = log_middleware,
    _M = _M,
    configure = _M.configure,
    update_config = _M.update_config
} 
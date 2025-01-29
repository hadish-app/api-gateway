local init = require "middleware.cors.cors_init"
local handlers = require "middleware.cors.cors_handlers"
local config = require "middleware.cors.cors_config"
-- Initialize with default config
local _M = {}

-- Create middleware handlers
local access_middleware = {
    name = "cors",
    routes = {},    -- Global middleware
    enabled = true,
    phase = "access",
    handle = handlers.handle_access
}

local header_filter_middleware = {
    name = "cors",
    routes = {},    -- Global middleware
    enabled = true,
    phase = "header_filter",
    handle = handlers.handle_header_filter
}

local log_middleware = {
    name = "cors",
    routes = {},    -- Global middleware
    enabled = true,
    phase = "log",
    handle = handlers.handle_log
}

return {
    access = access_middleware,
    header_filter = header_filter_middleware,
    log = log_middleware,
    init = init.init,
    configure = config.configure,
    update_config = config.update_config
} 
local middleware_chain = require "modules.core.middleware_chain"
local config = require "modules.middleware.cors.config"
local handlers = require "modules.middleware.cors.handlers"
local validators = require "modules.middleware.cors.validators"

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
    state = middleware_chain.STATES.ACTIVE,
    phase = "access",
    handle = handlers.handle_access
}

local header_filter_middleware = {
    name = "cors_header_filter",
    routes = {},    -- Global middleware
    state = middleware_chain.STATES.ACTIVE,
    phase = "header_filter",
    handle = handlers.handle_header_filter
}

local log_middleware = {
    name = "cors_log",
    routes = {},    -- Global middleware
    state = middleware_chain.STATES.ACTIVE,
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
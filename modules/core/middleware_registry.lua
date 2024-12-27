local _M = {}

-- Local references
local ngx = ngx
local log = ngx.log
local INFO = ngx.INFO
local DEBUG = ngx.DEBUG

-- Import middleware chain
local middleware_chain = require "modules.core.middleware_chain"

-- Table of middlewares
local REGISTRY = {
    request_id = {
        module = "modules.middleware.request_id",
        state = middleware_chain.STATES.ACTIVE
    }
    -- Add other core middlewares here
    -- example = {
    --     module = "modules.middleware.example",
    --     state = middleware_chain.STATES.INACTIVE
    -- }
}

-- Register a single middleware
local function register_middleware(name, config)
    log(DEBUG, "Registering middleware: ", name)
    
    local middleware = require(config.module)
    middleware_chain.use(middleware, middleware.name)
    middleware_chain.set_state(middleware.name, config.state)
    
    log(INFO, "Registered middleware: ", name)
    return true
end

-- Register all middlewares
function _M.register()
    log(INFO, "Registering all middlewares...")
    
    for name, config in pairs(REGISTRY) do
        local ok, err = register_middleware(name, config)
        if not ok then
            log(ngx.ERR, "Failed to register middleware: ", name, ", error: ", err)
            return nil, "Failed to register middleware: " .. name
        end
    end
    
    log(INFO, "Middlewares registered successfully")
    return true
end

return _M

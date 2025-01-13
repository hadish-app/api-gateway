local _M = {}

-- Local references
local ngx = ngx
local cjson = require "cjson"

-- Import middleware chain
local middleware_chain = require "modules.core.middleware_chain"

-- Define valid phases
local PHASES = {
    access = true,
    content = true,
    header_filter = true,
    body_filter = true,
    log = true
}

-- Table of middlewares with centralized priority management
local REGISTRY = {
    request_id = {
        module = "modules.middleware.request_id",
        state = middleware_chain.STATES.ACTIVE,
        multi_phase = true,  -- Indicate this is a multi-phase middleware
        phases = {
            access = {
                priority = 10  -- Run first to ensure request ID is available for logging
            },
            header_filter = {
                priority = 10  -- Keep same priority in header filter
            },
            log = {
                priority = 10  -- Keep same priority in log phase
            }
        }
    }
}

-- Helper function to format phases info
local function format_phases_info(phases)
    if not phases then return "{}" end
    return cjson.encode(phases)
end

-- Register a single middleware
local function register_middleware(name, config)
    ngx.log(ngx.DEBUG, "Registering middleware: ", name, ", config: ", cjson.encode(config))
    if config.multi_phase then
        -- Handle multi-phase middleware
        local middleware_module = require(config.module)
        
        -- Register each phase's middleware
        for phase, phase_config in pairs(config.phases) do
            if not PHASES[phase] then
                ngx.log(ngx.ERR, "Invalid phase for middleware: ", name, ", phase: ", phase)
                return nil, "Invalid phase: " .. phase
            end
            
            local middleware = middleware_module[phase]
            if not middleware then
                ngx.log(ngx.ERR, "Missing phase handler for middleware: ", name, ", phase: ", phase)
                return nil, "Missing phase handler: " .. phase
            end
            
            -- Override configuration
            middleware.priority = phase_config.priority or config.priority or 100
            middleware.state = config.state
            middleware.phase = phase  -- Set the phase field
            
            ngx.log(ngx.DEBUG, "Registering multi-phase middleware: ", name,
                ", phase: ", phase,
                ", priority: ", middleware.priority,
                ", state: ", middleware.state)
            
            middleware_chain.use(middleware, middleware.name)
            middleware_chain.set_state(middleware.name, middleware.state)
        end
    else
        -- Handle single-phase middleware (existing logic)
        if not config.phase then
            config.phase = "content"
        elseif not PHASES[config.phase] then
            ngx.log(ngx.ERR, "Invalid phase for middleware: ", name, ", phase: ", config.phase)
            return nil, "Invalid phase: " .. config.phase
        end
        
        local middleware = require(config.module)
        middleware.priority = config.priority or 100
        middleware.phase = config.phase
        middleware_chain.use(middleware, middleware.name)
        middleware_chain.set_state(middleware.name, config.state)
        
        ngx.log(ngx.DEBUG, "Registry: Registered single-phase middleware: ", name,
            ", priority: ", middleware.priority,
            ", phase: ", middleware.phase)
    end
    
    return true
end

-- Register all middlewares
function _M.register()
    ngx.log(ngx.DEBUG, "Registry: Registering all middlewares...")
    
    for name, config in pairs(REGISTRY) do
        ngx.log(ngx.DEBUG, "Registry: Registering middleware: ", name, 
            ", module: ", config.module,
            ", state: ", config.state,
            ", multi_phase: ", tostring(config.multi_phase),
            ", phases: ", format_phases_info(config.phases))
        local ok, err = register_middleware(name, config)
        if not ok then
            ngx.log(ngx.ERR, "Registry: Failed to register middleware: ", name, ", error: ", err)
            return nil, "Failed to register middleware: " .. name
        end
    end
    
    ngx.log(ngx.DEBUG, "Registry: Middlewares registered successfully")
    return true
end

-- Get the registry
function _M.get_registry()
    return REGISTRY
end

-- Get valid phases
function _M.get_phases()
    return PHASES
end

return _M 
local _M = {}

-- Local references
local ngx = ngx
local cjson = require "cjson"

-- Import middleware chain and registry
local middleware_chain = require "modules.core.middleware_chain"
local middleware_registry = require "middleware.registry"

-- Define valid phases
local PHASES = {
    access = true,
    content = true,
    header_filter = true,
    body_filter = true,
    log = true
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
            middleware.enabled = config.enabled or false
            middleware.phase = phase
            
            ngx.log(ngx.DEBUG, "Registering multi-phase middleware: ", name,
                ", phase: ", phase,
                ", priority: ", middleware.priority,
                ", enabled: ", tostring(middleware.enabled))
            
            middleware_chain.use(middleware, middleware.name)
            middleware_chain.set_state(middleware.name, middleware.enabled)
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
        middleware.enabled = config.enabled or false
        middleware_chain.use(middleware, middleware.name)
        middleware_chain.set_state(middleware.name, middleware.enabled)
        
        ngx.log(ngx.DEBUG, "Registry: Registered single-phase middleware: ", name,
            ", priority: ", middleware.priority,
            ", phase: ", middleware.phase,
            ", enabled: ", tostring(middleware.enabled))
    end
    
    return true
end

-- Register all middlewares
function _M.register()
    ngx.log(ngx.DEBUG, "Registry: Registering all middlewares...")
    
    for name, config in pairs(middleware_registry) do
        ngx.log(ngx.DEBUG, "Registry: Registering middleware: ", name, 
            ", module: ", config.module,
            ", enabled: ", tostring(config.enabled),
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

-- Get valid phases
function _M.get_phases()
    return PHASES
end

return _M 
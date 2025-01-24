local _M = {}

-- Local references
local ngx = ngx
local cjson = require "cjson"
local router = require "modules.core.router"
local spec_loader = require "modules.core.spec_loader"

-- Helper function to format route info
local function format_route_info(route)
    return string.format("%s %s -> %s", route.method, route.path, route.handler)
end

-- Register a single service
local function register_service(name, config)
    ngx.log(ngx.DEBUG, "Registering service: ", name, ", config: ", cjson.encode(config))
    
    -- Load the service module
    local service = require(config.module)
    if not service then
        ngx.log(ngx.ERR, "Failed to load service module: ", config.module)
        return nil, "Failed to load service module"
    end
    
    -- Register each route
    for _, route in ipairs(config.routes) do
        -- Verify handler exists
        if not service[route.handler] then
            ngx.log(ngx.ERR, "Handler not found in service: ", route.handler)
            return nil, "Handler not found: " .. route.handler
        end
        
        -- Create handler function that calls the service's handler
        local handler = function()
            return service[route.handler]()
        end
        
        -- Register route with the router
        local ok, err = router.register(route.path, handler, route.method)
        if not ok then
            ngx.log(ngx.ERR, "Failed to register route: ", format_route_info(route), ", error: ", err)
            return nil, "Failed to register route: " .. format_route_info(route)
        end
        
        ngx.log(ngx.DEBUG, "Registered route: ", format_route_info(route))
    end
    
    return true
end

-- Register all services
function _M.register()
    ngx.log(ngx.DEBUG, "Registry: Loading service specs...")
    
    -- Get NGINX prefix path and construct services path
    local nginx_prefix = ngx.config.prefix()
    local services_path = nginx_prefix .. "services"
    
    ngx.log(ngx.DEBUG, "Registry: Using services path: ", services_path)
    
    -- Load services from specs using dynamic path
    local services = spec_loader.load_services(services_path)
    if not services then
        ngx.log(ngx.ERR, "Registry: Failed to load service specs")
        return nil, "Failed to load service specs"
    end
    
    ngx.log(ngx.DEBUG, "Registry: Registering all services...")
    
    for name, config in pairs(services) do
        ngx.log(ngx.DEBUG, "Registry: Registering service: ", name, 
            ", module: ", config.module)
        local ok, err = register_service(name, config)
        if not ok then
            ngx.log(ngx.ERR, "Registry: Failed to register service: ", name, ", error: ", err)
            return nil, "Failed to register service: " .. name
        end
    end
    
    ngx.log(ngx.DEBUG, "Registry: Services registered successfully")
    return true
end

return _M 
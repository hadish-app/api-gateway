local ngx = ngx
local cjson = require "cjson"

local _M = {}

-- Table to store route handlers
local routes = {}

-- Helper function to split path into segments
local function split_path(path)
    local segments = {}
    for segment in path:gmatch("[^/]+") do
        table.insert(segments, segment)
    end
    return segments
end

-- Register a route handler
function _M.register(service_name, service_id, route_id, path, method, cors, route_handler)
    ngx.log(ngx.DEBUG, "[Router Module] Registering route - service_name: " .. service_name .. ", service_id: " .. service_id .. ", route_id: " .. route_id .. ", path: " .. path .. ", method: " .. method .. ", cors: " .. cjson.encode(cors))

    -- Validate path parameter
    if not path then
        ngx.log(ngx.ERR, "Path is required")
        return nil, "Path is required"
    end

    -- Validate route_handler parameter 
    if not route_handler then
        ngx.log(ngx.ERR, "Route handler is required")
        return nil, "Route handler is required"
    end
    
    -- Ensure routes table exists for this path
    routes[path] = routes[path] or {}
    
    -- If method is specified, register for specific method
    if method then
        routes[path][method:upper()] = {
            service_name = service_name,
            service_id = service_id,
            route_id = route_id,
            handler = route_handler,
            cors = cors,
        }
        ngx.log(ngx.DEBUG, "[Router Module] Registered route - path: " .. path .. ", method: " .. method:upper() .. ", service_name: " .. service_name .. ", service_id: " .. service_id .. ", route_id: " .. route_id)
    else
        -- If no method specified, use same route handler for all methods
        routes[path]["ANY"] = {
            service_name = service_name,
            service_id = service_id,
            route_id = route_id,
            handler = route_handler,
            cors = cors,
        }
        ngx.log(ngx.DEBUG, "[Router Module] Registered route - path: " .. path .. ", method: ANY, service_name: " .. service_name .. ", service_id: " .. service_id .. ", route_id: " .. route_id)
    end
    return true
end

-- Find matching route and handler
function _M.match(uri, method)
    ngx.log(ngx.DEBUG, "[Router Module] Matching route - uri: " .. uri .. ", method: " .. method)

    -- Get path segments
    local request_segments = split_path(uri)
    
    -- Try exact match first
    if routes[uri] then
        local route = routes[uri]
        -- Check for method-specific handler
        if route[method] then
            ngx.log(ngx.DEBUG, "[Router Module] Matched route - uri: " .. uri .. ", method: " .. method .. ", service_name: " .. route[method].service_name .. ", service_id: " .. route[method].service_id .. ", route_id: " .. route[method].route_id)
            return route[method].handler, uri
        -- Fall back to ANY method handler
        elseif route["ANY"] then
            ngx.log(ngx.DEBUG, "[Router Module] Matched route - uri: " .. uri .. ", method: ANY, service_name: " .. route["ANY"].service_name .. ", service_id: " .. route["ANY"].service_id .. ", route_id: " .. route["ANY"].route_id)
            return route["ANY"].handler, uri
        end
    end
    
    -- Try pattern matching if no exact match
    for path, handlers in pairs(routes) do
        local path_segments = split_path(path)
        
        -- Skip if segment count doesn't match
        if #path_segments == #request_segments then
            local params = {}
            local matches = true
            
            -- Compare segments
            for i, path_segment in ipairs(path_segments) do
                local request_segment = request_segments[i]
                
                -- Check if path segment is a parameter
                if path_segment:match("^{.+}$") then
                    -- Extract parameter name
                    local param_name = path_segment:match("^{(.+)}$")
                    params[param_name] = request_segment
                elseif path_segment ~= request_segment then
                    matches = false
                    break
                end
            end
            
            if matches then
                -- Store params in context
                ngx.ctx.router_params = params
                
                -- Return appropriate handler
                if handlers[method] then
                    ngx.log(ngx.DEBUG, "[Router Module] Matched route - uri: " .. uri .. ", method: " .. method .. ", service_name: " .. handlers[method].service_name .. ", service_id: " .. handlers[method].service_id .. ", route_id: " .. handlers[method].route_id)
                    return handlers[method].handler, path
                elseif handlers["ANY"] then
                    ngx.log(ngx.DEBUG, "[Router Module] Matched route - uri: " .. uri .. ", method: ANY, service_name: " .. handlers["ANY"].service_name .. ", service_id: " .. handlers["ANY"].service_id .. ", route_id: " .. handlers["ANY"].route_id)
                    return handlers["ANY"].handler, path
                end
            end
        end
    end
    
    return nil, nil
end

function _M.get_routes()
    return routes
end

return _M 

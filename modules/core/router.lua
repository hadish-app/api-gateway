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
function _M.register(path, service, method)
    ngx.log(ngx.DEBUG, "[Router Module] Registering route - path: " .. path .. ", method: " .. method)

    -- Validate path parameter
    if not path then
        ngx.log(ngx.ERR, "Path is required")
        return nil, "Path is required"
    end

    -- Validate service parameter 
    if not service then
        ngx.log(ngx.ERR, "Service is required")
        return nil, "Service is required"
    end
    
    -- Ensure routes table exists for this path
    routes[path] = routes[path] or {}
    
    -- If method is specified, register for specific method
    if method then
        routes[path][method:upper()] = service
        ngx.log(ngx.DEBUG, "[Router Module] Registered route - path: " .. path .. ", method: " .. method:upper())
    else
        -- If no method specified, use same handler for all methods
        routes[path]["ANY"] = service
        ngx.log(ngx.DEBUG, "[Router Module] Registered route - path: " .. path .. ", method: ANY")
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
        local handlers = routes[uri]
        -- Check for method-specific handler
        if handlers[method] then
            ngx.log(ngx.DEBUG, "[Router Module] Matched route - uri: " .. uri .. ", method: " .. method)
            return handlers[method], uri
        -- Fall back to ANY method handler
        elseif handlers["ANY"] then
            ngx.log(ngx.DEBUG, "[Router Module] Matched route - uri: " .. uri .. ", method: ANY")
            return handlers["ANY"], uri
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
                    return handlers[method], path
                elseif handlers["ANY"] then
                    return handlers["ANY"], path
                end
            end
        end
    end
    
    return nil, nil
end

-- Handle the request using the matched service
function _M.handle_request()    
    local method = ngx.req.get_method()
    local uri = ngx.var.uri
    
    ngx.log(ngx.DEBUG, "[Router Module] Handling request - method: " .. method .. ", uri: " .. uri)

    -- Find matching service
    local handler, matched_route = _M.match(uri, method)
    ngx.log(ngx.DEBUG, "[Router Module] Matched service - uri: " .. uri .. ", method: " .. method)

    if not handler then
        -- Log detailed request information for debugging
        ngx.log(ngx.WARN, string.format(
            "No route found - Method: %s, URI: %s, Headers: %s",
            method,
            uri,
            cjson.encode(ngx.req.get_headers())
        ))

        -- Set status and headers
        ngx.status = 404
        ngx.header["Content-Type"] = "application/json"

        -- Return structured error response
        ngx.say(cjson.encode({
            error = "Not Found",
            message = string.format("No matching route found for %s %s. Please check the API documentation for available endpoints.", method, uri),
            request_id = ngx.var.request_id or "unknown"
        }))

        return ngx.exit(404)
    end
    
    ngx.log(ngx.DEBUG, string.format("Route matched - %s %s -> %s", 
        method, uri, matched_route))
    
    -- Execute the handler function directly
    local ok, err = pcall(handler)
    
    if not ok then
        ngx.log(ngx.ERR, string.format("Error handling request: %s", err))
        ngx.status = 500
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({
            error = "Internal Server Error",
            message = "Failed to process request"
        }))
        return ngx.exit(500)
    end
end

return _M 
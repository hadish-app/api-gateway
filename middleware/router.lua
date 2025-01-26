local cjson = require "cjson"
local middleware_chain = require "modules.core.middleware_chain"
local route_registry = require "modules.core.route_registry"
local ngx = ngx

-- Handle the request using the matched service
local function handle_request()    
    local method = ngx.req.get_method()
    local uri = ngx.var.uri
    
    ngx.log(ngx.DEBUG, "[Router Module] Handling request - method: " .. method .. ", uri: " .. uri)

    -- Find matching service
    local handler, matched_route = route_registry.match(uri, method)
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

-- Create content phase middleware
local content_middleware = {
    name = "router",
    enabled = true,
    phase = "content",
    handle = function(self)    
        ngx.log(ngx.DEBUG, "[Router Middleware] Handling request")
        return handle_request()
    end
}

return content_middleware
local ngx = ngx
local _M = {}

-- Tables to store middleware
local global_middleware = {}  -- For all routes
local route_middleware = {}   -- Per-route middleware

-- Context key for terminated middleware
local TERMINATED_KEY = "terminated_middleware"

-- Helper function to validate middleware
local function validate_middleware(handler, name)
    if type(handler) ~= "table" then
        error("Middleware must be a table, got: " .. type(handler))
    end
    
    if type(handler.handle) ~= "function" then
        error("Middleware must have a handle function")
    end
    
    if not (name or handler.name) then
        error("Middleware name is required")
    end

    handler.name = name or handler.name

    -- Validate and set enabled flag
    if handler.enabled ~= nil then
        if type(handler.enabled) ~= "boolean" then
            ngx.log(ngx.ERR, "Middleware enabled flag must be boolean, got: " .. type(handler.enabled))
            error("Middleware enabled flag must be boolean, got: " .. type(handler.enabled))
        end
    else
        handler.enabled = false
    end

    handler.routes = handler.routes or {}  -- Empty means global
    handler.phase = handler.phase or "content"  -- Default to content phase
    
    -- Priority will be set by registry if not provided
    if handler.priority then
        handler.priority = handler.priority
    end
    
    ngx.log(ngx.DEBUG, "Validated middleware: ", name, ", enabled: ", tostring(handler.enabled), ", phase: ", handler.phase)
end

-- Add middleware to the chain
function _M.use(handler, name)
    validate_middleware(handler, name)
    
    -- Determine if route-specific or global
    if #handler.routes > 0 then
        -- Store per route
        for _, route in ipairs(handler.routes) do
            route_middleware[route] = route_middleware[route] or {}
            table.insert(route_middleware[route], handler)
            ngx.log(ngx.DEBUG, "Added route middleware: ", name, " for route: ", route)
        end
    else
        -- Store globally
        table.insert(global_middleware, handler)
        ngx.log(ngx.DEBUG, "Added global middleware: ", name)
    end
    
    -- Sort middleware by priority (lower numbers run first)
    local function sort_by_priority(a, b)
        return a.priority < b.priority
    end
    
    table.sort(global_middleware, sort_by_priority)
    for _, route_handlers in pairs(route_middleware) do
        table.sort(route_handlers, sort_by_priority)
    end
end

-- Remove middleware by name
function _M.remove(name)
    -- Remove from global middleware
    for i, m in ipairs(global_middleware) do
        if m.name == name then
            table.remove(global_middleware, i)
            ngx.log(ngx.DEBUG, "Removed global middleware: ", name)
            break
        end
    end
    
    -- Remove from route middleware
    for route, handlers in pairs(route_middleware) do
        for i, m in ipairs(handlers) do
            if m.name == name then
                table.remove(handlers, i)
                ngx.log(ngx.DEBUG, "Removed route middleware: ", name, " from route: ", route)
                break
            end
        end
    end
end

-- Enable/disable middleware
function _M.set_state(name, enabled)
    -- Validate enabled parameter is boolean
    if type(enabled) ~= "boolean" then
        ngx.log(ngx.ERR, "Middleware enabled flag must be boolean, got: " .. type(enabled))
        error("Middleware enabled flag must be boolean, got: " .. type(enabled))
    end

    local function update_enabled(middleware_list)
        for _, m in ipairs(middleware_list) do
            if m.name == name then
                -- Set enabled flag, defaulting to false if not present
                m.enabled = enabled
                ngx.log(ngx.DEBUG, "Updated enabled status for middleware: ", name, " to: ", tostring(enabled))
                return true
            end
        end
        return false
    end
    
    -- Update in global middleware
    if update_enabled(global_middleware) then
        return true
    end
    
    -- Update in route middleware
    for _, handlers in pairs(route_middleware) do
        if update_enabled(handlers) then
            return true
        end
    end
    
    -- Throw error if middleware not found
    ngx.log(ngx.ERR, "Middleware not found: ", name)
    error("Middleware not found: " .. tostring(name))
end

-- Get middleware chain for a specific route
function _M.get_chain(route, phase)
    local chain = {}
    phase = phase or "content"  -- Default to content phase
    
    -- Add global middleware for the specified phase
    for _, m in ipairs(global_middleware) do
        if m.enabled and m.phase == phase then
            table.insert(chain, m)
            ngx.log(ngx.DEBUG, "Added active global middleware to chain: ", m.name, " for phase: ", phase)
        end
    end
    
    -- Add route-specific middleware for the specified phase
    if route and route_middleware[route] then
        for _, m in ipairs(route_middleware[route]) do
            if m.enabled and m.phase == phase then
                table.insert(chain, m)
                ngx.log(ngx.DEBUG, "Added active route middleware to chain: ", m.name, " for route: ", route, " and phase: ", phase)
            end
        end
    end
    
    return chain
end

-- Execute middleware chain for a route
function _M.run(route, phase)
    local chain = _M.get_chain(route, phase)
    ngx.log(ngx.DEBUG, "Running middleware chain for route: ", route, ", phase: ", phase, ", chain length: ", #chain)
    
    for _, middleware in ipairs(chain) do
        -- Skip disabled middleware
        if not middleware.enabled then
            ngx.log(ngx.DEBUG, "Skipping disabled middleware: ", middleware.name)
            goto continue
        end
        
        ngx.log(ngx.DEBUG, "Executing middleware: ", middleware.name)
        
        -- Execute with error handling
        local ok, result = pcall(function() return middleware:handle() end)
        if not ok then
            ngx.log(ngx.ERR, "Middleware error in ", middleware.name, ": ", result)
            error("Middleware " .. middleware.name .. " failed: " .. tostring(result))
        end
        
        -- If handler returns false, stop the chain
        if result == false then
            ngx.log(ngx.DEBUG, "Middleware chain stopped by: ", middleware.name)
            return false
        end
        
        ::continue::
    end
    
    ngx.log(ngx.DEBUG, "Middleware chain completed successfully for phase: ", phase)
    return true
end

-- Initialize default middleware
function _M.init()
    -- No default middleware for now
end

-- Add a reset function to the module
function _M.reset()
    local info = debug.getinfo(2, "Sln")
    local caller = info.short_src .. ":" .. info.currentline
    ngx.log(ngx.DEBUG, "Resetting middleware chain, called from: ", caller)
    
    -- Clear the middleware tables
    for k in pairs(global_middleware) do
        global_middleware[k] = nil
    end
    for k in pairs(route_middleware) do
        route_middleware[k] = nil
    end
    ngx.log(ngx.DEBUG, "Middleware chain reset complete")
end

-- Execute middleware chain for a route with error handling
function _M.run_chain(phase)
    local uri = ngx.var.uri
    local chain = _M.get_chain(uri, phase)
    
    ngx.log(ngx.DEBUG, "Middleware chain for phase: ", phase, " chain length: ", #chain)

    -- Initialize terminated middleware tracking if not exists
    ngx.ctx[TERMINATED_KEY] = ngx.ctx[TERMINATED_KEY] or {}
    local terminated = ngx.ctx[TERMINATED_KEY]

    local ok, err = pcall(function()
        for _, middleware in ipairs(chain) do
            -- Skip disabled middleware
            if not middleware.enabled then
                ngx.log(ngx.DEBUG, "Skipping disabled middleware: ", middleware.name)
                goto continue
            end

            -- Skip if this middleware was terminated in a previous phase
            if phase ~= "log" and terminated[middleware.name] then
                ngx.log(ngx.DEBUG, "Skipping terminated middleware: ", middleware.name)
                goto continue
            end
            
            ngx.log(ngx.DEBUG, "Executing middleware: ", middleware.name, " for phase: ", phase)
            
            -- Execute with error handling
            local ok, result = pcall(function() return middleware:handle() end)
            if not ok then
                ngx.log(ngx.ERR, "Middleware error in ", middleware.name, ": ", result)
                error("Middleware " .. middleware.name .. " failed: " .. tostring(result))
            end
            
            -- If handler returns false, mark only this middleware as terminated
            if result == false then
                ngx.log(ngx.DEBUG, "Middleware terminated: ", middleware.name)
                terminated[middleware.name] = true
            end
            
            ::continue::
        end
        
        ngx.log(ngx.DEBUG, "Middleware chain completed successfully for phase: ", phase)
        return true
    end)
    
    if not ok then
        ngx.log(ngx.ERR, "Middleware chain error in phase ", phase, ": ", err)
        ngx.status = 500
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    -- Clean up terminated middleware tracking in log phase
    if phase == "log" then
        ngx.ctx[TERMINATED_KEY] = nil
    end
    
    return err
end

return _M

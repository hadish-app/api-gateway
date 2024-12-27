local logger = require "modules.utils.logger"
local _M = {}

-- Tables to store middleware
local global_middleware = {}  -- For all routes
local route_middleware = {}   -- Per-route middleware

-- Middleware states
local STATES = {
    ACTIVE = "active",
    DISABLED = "disabled"
}

-- Helper function to validate state
local function is_valid_state(state)
    for _, valid_state in pairs(STATES) do
        if state == valid_state then
            return true
        end
    end
    return false
end

-- Helper function to validate middleware
local function validate_middleware(handler, name)
    if type(handler) ~= "table" then
        error("Middleware must be a table, got: " .. type(handler))
    end
    
    if type(handler.handle) ~= "function" then
        error("Middleware must have a handle function")
    end
    
    -- Set defaults if not provided
    handler.name = name or handler.name or "unnamed_middleware"
    handler.priority = handler.priority or 100
    handler.state = handler.state or STATES.DISABLED
    handler.routes = handler.routes or {}  -- Empty means global
    
    logger.debug("Validated middleware:", name, ", state:", handler.state)
end

-- Add middleware
function _M.use(handler, name)
    validate_middleware(handler, name)
    
    -- Determine if route-specific or global
    if #handler.routes > 0 then
        -- Store per route
        for _, route in ipairs(handler.routes) do
            route_middleware[route] = route_middleware[route] or {}
            table.insert(route_middleware[route], handler)
            logger.debug("Added route middleware:", name, "for route:", route)
        end
    else
        -- Store globally
        table.insert(global_middleware, handler)
        logger.debug("Added global middleware:", name)
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
            logger.debug("Removed global middleware:", name)
            break
        end
    end
    
    -- Remove from route middleware
    for route, handlers in pairs(route_middleware) do
        for i, m in ipairs(handlers) do
            if m.name == name then
                table.remove(handlers, i)
                logger.debug("Removed route middleware:", name, "from route:", route)
                break
            end
        end
    end
end

-- Enable/disable middleware
function _M.set_state(name, state)
    if not is_valid_state(state) then
        error("Invalid state: " .. tostring(state))
    end
    
    local function update_state(middleware_list)
        for _, m in ipairs(middleware_list) do
            if m.name == name then
                m.state = state
                logger.debug("Updated state for middleware:", name, "to:", state)
                return true
            end
        end
        return false
    end
    
    -- Update in global middleware
    if update_state(global_middleware) then
        return true
    end
    
    -- Update in route middleware
    for _, handlers in pairs(route_middleware) do
        if update_state(handlers) then
            return true
        end
    end
    
    -- Throw error if middleware not found
    logger.error("Middleware not found:", name)
    error("Middleware not found: " .. tostring(name))
end

-- Get middleware chain for a specific route
function _M.get_chain(route)
    local chain = {}
    
    -- Add global middleware
    for _, m in ipairs(global_middleware) do
        if m.state == STATES.ACTIVE then
            table.insert(chain, m)
            logger.debug("Added active global middleware to chain:", m.name)
        else
            logger.debug("Skipped inactive global middleware:", m.name)
        end
    end
    
    -- Add route-specific middleware
    if route and route_middleware[route] then
        for _, m in ipairs(route_middleware[route]) do
            if m.state == STATES.ACTIVE then
                table.insert(chain, m)
                logger.debug("Added active route middleware to chain:", m.name, "for route:", route)
            else
                logger.debug("Skipped inactive route middleware:", m.name, "for route:", route)
            end
        end
    end
    
    return chain
end

-- Execute middleware chain for a route
function _M.run(route)
    local chain = _M.get_chain(route)
    logger.debug("Running middleware chain for route:", route, ", chain length:", #chain)
    
    for _, middleware in ipairs(chain) do
        -- Skip disabled middleware
        if middleware.state ~= STATES.ACTIVE then
            logger.debug("Skipping disabled middleware:", middleware.name)
            goto continue
        end
        
        logger.debug("Executing middleware:", middleware.name)
        
        -- Execute with error handling
        local ok, result = pcall(function() return middleware:handle() end)
        if not ok then
            logger.error("Middleware error in", middleware.name .. ":", result)
            error("Middleware " .. middleware.name .. " failed: " .. tostring(result))
        end
        
        -- If handler returns false, stop the chain
        if result == false then
            logger.debug("Middleware chain stopped by:", middleware.name)
            return false
        end
        
        ::continue::
    end
    
    logger.debug("Middleware chain completed successfully")
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
    logger.debug("Resetting middleware chain, called from:", caller)
    
    -- Clear the middleware tables
    for k in pairs(global_middleware) do
        global_middleware[k] = nil
    end
    for k in pairs(route_middleware) do
        route_middleware[k] = nil
    end
    logger.debug("Middleware chain reset complete")
end

-- Export states
_M.STATES = STATES

return _M

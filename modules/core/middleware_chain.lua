-- TODO: Implement core middleware framework
    -- Support both global and route-specific middleware
    -- Allow for easy addition of new middleware
    -- Allow for easy removal of middleware
    -- Allow for easy modification of middleware
    -- Allow for easy addition of new routes
    -- Allow for easy removal of routes
    -- Allow for easy modification of routes

    -- Example implementation showing middleware chain usage:
    -- local chain = require("middleware_chain")    
    -- local logging = require("middleware.logging.logging")
    -- if config.enable_cors then
    --     chain.use(require("middleware.security.cors"))
    -- end    
    -- chain.use(logging)   -- Add request/response logging middleware

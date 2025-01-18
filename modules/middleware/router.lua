local middleware_chain = require "modules.core.middleware_chain"
local router = require "modules.core.router"
local ngx = ngx

-- Create content phase middleware
local content_middleware = {
    name = "router",
    state = middleware_chain.STATES.ACTIVE,
    phase = "content",
    handle = function(self)
        ngx.log(ngx.DEBUG, "Executing middleware: ", self.name)
        return router.handle_request()
    end


}

return content_middleware
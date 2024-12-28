local middleware_chain = require "modules.core.middleware_chain"

local _M = {}

-- Run middleware chain for any endpoint
-- @return boolean: true if processing should continue, false if chain was interrupted
function _M.run()
    local ok, err = pcall(function()
        return middleware_chain.run(ngx.var.uri)
    end)
    
    if not ok then
        ngx.log(ngx.ERR, "Middleware chain error: ", err)
        ngx.status = 500
        ngx.say("Internal Server Error")
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    
    -- If chain returns false, stop processing
    if err == false then
        return ngx.exit(ngx.HTTP_OK)
    end
    
    return true
end

return _M 
local _M = {}

local rate_limiter = require "rate_limiter"
local config = require "config"

-- Handle admin access with rate limiting
function _M.handle_access()
    local ip = ngx.var.remote_addr
    
    -- Check rate limit
    if rate_limiter.should_limit_request(ip) then
        return ngx.exit(429)
    end
    
    -- Set the backend URL
    ngx.var.backend = config.admin_service.url
end

return _M 
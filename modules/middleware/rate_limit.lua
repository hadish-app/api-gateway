local limit_req = require "resty.limit.req"
local _M = {}

local lim

function _M.init()
    local err
    lim, err = limit_req.new("rate_limit_store", 200, 100)  -- 200 requests per second, burst 100
    if not lim then
        ngx.log(ngx.ERR, "failed to instantiate a resty.limit.req object: ", err)
        return
    end
end

function _M.execute(ctx)
    if not lim then
        return true
    end

    local key = ngx.var.binary_remote_addr
    local delay, err = lim:incoming(key, true)
    
    if not delay then
        if err == "rejected" then
            return ngx.exit(429)  -- Too Many Requests
        end
        ngx.log(ngx.ERR, "failed to limit request: ", err)
        return true
    end

    if delay > 0 then
        ngx.sleep(delay)
    end
    
    -- Add rate limit headers
    local remaining, err = lim:remaining(key)
    if not err then
        ngx.header["X-RateLimit-Remaining"] = remaining
        ngx.header["X-RateLimit-Limit"] = "200"
    end
    
    return true
end

return _M 
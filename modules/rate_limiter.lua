local _M = {}

local config = require "config"

-- Function to check if request should be rate limited
function _M.should_limit_request(ip)
    local limit = config.rate_limit.requests_per_second
    local current_time = ngx.time()
    local time_window = 1  -- 1 second window
    
    -- Get the rate limit key for this IP
    local rate_key = string.format("rate:%s", ip)
    local rate_limit_dict = ngx.shared.rate_limit_count
    
    -- Get current count and last update time
    local count, flags, stale = rate_limit_dict:get_stale(rate_key)
    local last_time = rate_limit_dict:get(rate_key .. ":time") or 0
    
    -- If we're in a new time window, reset the counter
    if current_time - last_time >= time_window then
        count = 0
    end
    
    -- Increment the counter
    count = (count or 0) + 1
    
    -- Update the counter and timestamp
    rate_limit_dict:set(rate_key, count, time_window)
    rate_limit_dict:set(rate_key .. ":time", current_time, time_window)
    
    -- Check if we're over the limit
    if count > limit then
        -- Allow burst
        if count <= (limit + config.rate_limit.burst) then
            return false
        end
        return true
    end
    
    return false
end

return _M 
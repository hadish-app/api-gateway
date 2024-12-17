local _M = {}

local utils = require "utils"
local ip_ban = require "ip_ban"
local config = require "config"

-- Initialize shared dictionaries
local rate_limit_count = ngx.shared.rate_limit_count

-- Function to check if request should be rate limited
function _M.should_limit_request(ip)
    local limit = config.rate_limit.requests_per_second
    local burst = config.rate_limit.burst
    local time_window = config.rate_limit.violation_expiry
    local current_time = ngx.time()
    
    -- Get the rate limit keys for this IP
    local count_key = string.format("count:%s", ip)
    local violations_key = string.format("violations:%s", ip)
    local last_time_key = string.format("last_time:%s", ip)
    
    -- Get current counts and last update time
    local request_count = rate_limit_count:get(count_key) or 0
    local violations = rate_limit_count:get(violations_key) or 0
    local last_time = rate_limit_count:get(last_time_key) or 0
    
    -- If we're in a new time window, reset the counters
    if current_time - last_time >= time_window then
        request_count = 0
        violations = 0
        rate_limit_count:set(count_key, 0, time_window)
        rate_limit_count:set(violations_key, 0, time_window)
        rate_limit_count:set(last_time_key, current_time, time_window)
    end
    
    -- Check if IP is already banned
    if violations >= config.rate_limit.violations_before_ban then
        -- Ban the IP
        ip_ban.ban_ip(ip)
        
        -- Clear tracking
        rate_limit_count:delete(count_key)
        rate_limit_count:delete(violations_key)
        rate_limit_count:delete(last_time_key)
        
        -- Return banned response
        ngx.status = 403
        ngx.header.content_type = "application/json"
        ngx.var.violation_type = "IP_BANNED"
        ngx.var.details = string.format("IP banned for %d seconds due to excessive violations", config.ip_ban.duration)
        ngx.say(string.format('{"error": "IP banned for %d seconds due to excessive violations"}', config.ip_ban.duration))
        return ngx.exit(403)
    end
    
    -- Increment the request counter atomically
    local success, err, forcible = rate_limit_count:incr(count_key, 1, 0, time_window)
    if not success then
        rate_limit_count:set(count_key, 1, time_window)
        request_count = 1
    else
        request_count = success
    end
    
    -- Set rate limit headers
    ngx.header["X-RateLimit-Limit"] = limit + burst
    ngx.header["X-RateLimit-Remaining"] = math.max(0, (limit + burst) - request_count)
    ngx.header["X-RateLimit-Reset"] = last_time + time_window
    
    -- Check if we're over the combined limit
    if request_count > (limit + burst) then
        -- Increment violations
        success, err, forcible = rate_limit_count:incr(violations_key, 1, 0, time_window)
        if not success then
            rate_limit_count:set(violations_key, 1, time_window)
            violations = 1
        else
            violations = success
        end
        
        -- Log the violation
        ngx.log(ngx.WARN, string.format(
            "[%s] Security Event [RATE_LIMIT_WARNING] - IP: %s, Details: Violation count: %d/%d",
            utils.get_iso8601_timestamp(),
            ip,
            violations,
            config.rate_limit.violations_before_ban
        ))
        
        -- Return rate limited response
        ngx.status = 429
        ngx.header.content_type = "application/json"
        ngx.var.violation_type = "RATE_LIMIT_EXCEEDED"
        ngx.var.details = string.format("Rate limit exceeded (%d/%d violations)", 
            violations,
            config.rate_limit.violations_before_ban
        )
        ngx.say(string.format(
            '{"error": "Rate limit exceeded. %d more violations will result in a temporary ban."}',
            config.rate_limit.violations_before_ban - violations
        ))
        return ngx.exit(429)
    end
    
    return false
end

return _M 
local _M = {}

local utils = require "utils"
local ip_ban = require "ip_ban"
local config = require "config"

-- Initialize shared dictionaries
local rate_limit_count = ngx.shared.rate_limit_count

-- Function to check rate limit count and ban if needed
function _M.check_rate_limit(ip)
    local count = rate_limit_count:get(ip) or 0
    if count >= config.rate_limit.violations_before_ban then  -- Ban after configured violations
        ip_ban.ban_ip(ip)
        rate_limit_count:delete(ip)
        return true
    else
        rate_limit_count:incr(ip, 1, 0, config.rate_limit.violation_expiry)  -- Increment count, expire after configured window
        ngx.log(ngx.WARN, string.format(
            "[%s] Security Event [RATE_LIMIT_WARNING] - IP: %s, Details: Violation count: %d/%d",
            utils.get_iso8601_timestamp(),
            ip,
            count + 1,
            config.rate_limit.violations_before_ban
        ))
        return false
    end
end

-- Handle rate limit exceeded response
function _M.handle_rate_limited()
    local ip = ngx.var.remote_addr
    if _M.check_rate_limit(ip) then
        ngx.status = 403
        ngx.header.content_type = "application/json"
        ngx.var.violation_type = "IP_BANNED"
        ngx.var.details = "IP banned due to excessive rate limit violations"
        ngx.say('{"error": "IP banned due to excessive rate limit violations"}')
    else
        ngx.status = 429
        ngx.header.content_type = "application/json"
        ngx.var.violation_type = "RATE_LIMIT_EXCEEDED"
        ngx.var.details = "Rate limit exceeded"
        ngx.say('{"error": "Rate limit exceeded. Further violations will result in a temporary ban."}')
    end
    return ngx.exit(ngx.status)
end

return _M 
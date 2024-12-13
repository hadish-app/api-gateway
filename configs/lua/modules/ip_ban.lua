local _M = {}
local utils = require "utils"
local config = require "config"

-- Function to ban an IP
function _M.ban_ip(ip)
    local blacklist = ngx.shared.ip_blacklist
    local ban_duration = config.ban_duration_seconds
    local ban_until = ngx.time() + ban_duration
    
    -- Store the ban information
    local success, err, forcible = blacklist:set(ip, ban_until)
    if not success then
        ngx.log(ngx.ERR, string.format("[%s] Failed to ban IP %s: %s", 
            utils.get_iso8601_timestamp(),
            ip, 
            err or "unknown error"
        ))
        return
    end
    
    -- Log detailed ban information
    ngx.log(ngx.WARN, string.format(
        "[%s] Security Event [IP_BANNED] - IP: %s, Ban Start: %s, Ban Until: %s (duration: %d seconds)",
        utils.get_iso8601_timestamp(),
        ip,
        os.date("%Y-%m-%d %H:%M:%S", ngx.time()),
        os.date("%Y-%m-%d %H:%M:%S", ban_until),
        ban_duration
    ))
    
    -- Create or update banned_ips.conf
    local f = io.open("/etc/nginx/banned_ips.conf", "w")
    if f then
        f:write("# Banned IPs Configuration\n")
        f:write("# Format: deny IP_ADDRESS;\n\n")
        f:write("# Auto-generated - DO NOT EDIT\n")
        f:write(string.format("# Ban Start: %s\n", os.date("%Y-%m-%d %H:%M:%S", ngx.time())))
        f:write(string.format("# Ban Until: %s\n", os.date("%Y-%m-%d %H:%M:%S", ban_until)))
        f:write("geo $banned_ip {\n")
        f:write("    default 0;\n")
        f:write("    " .. ip .. " 1;\n")
        f:write("}\n\n")
        f:write("map $banned_ip $banned_response {\n")
        f:write("    0 '';\n")
        f:write(string.format('    1 \'{"error": "IP temporarily banned due to excessive requests. Try again in %s."}\';\n',
            utils.format_duration(ban_duration)))
        f:write("}\n")
        f:close()
        -- Force nginx to reload the configuration
        os.execute("nginx -s reload")
    else
        ngx.log(ngx.ERR, string.format("[%s] Failed to open banned_ips.conf for writing", utils.get_iso8601_timestamp()))
    end
end

-- Function to check if IP is banned
function _M.is_ip_banned(ip)
    local blacklist = ngx.shared.ip_blacklist
    local ban_until = blacklist:get(ip)
    
    if ban_until then
        local current_time = ngx.time()
        local remaining_time = ban_until - current_time
        
        ngx.log(ngx.INFO, string.format(
            "[%s] Ban check for IP %s - Current Time: %s, Ban Until: %s, Remaining: %d seconds",
            utils.get_iso8601_timestamp(),
            ip,
            os.date("%Y-%m-%d %H:%M:%S", current_time),
            os.date("%Y-%m-%d %H:%M:%S", ban_until),
            remaining_time
        ))
        
        if current_time < ban_until then
            ngx.log(ngx.WARN, string.format(
                "[%s] Security Event [BANNED_REQUEST_BLOCKED] - IP: %s, Ban expires in %d seconds",
                utils.get_iso8601_timestamp(),
                ip,
                remaining_time
            ))
            return true
        end
    end
    return false
end

-- Function to check rate limit count and ban if needed
function _M.check_rate_limit(ip)
    local count = ngx.shared.rate_limit_count:get(ip) or 0
    if count >= config.max_rate_limit_violations then
        _M.ban_ip(ip)
        ngx.shared.rate_limit_count:delete(ip)
        return true
    else
        ngx.shared.rate_limit_count:incr(ip, 1, 0, config.rate_limit_window)
        ngx.log(ngx.WARN, string.format(
            "[%s] Security Event [RATE_LIMIT_WARNING] - IP: %s, Details: Violation count: %d/%d",
            utils.get_iso8601_timestamp(),
            ip,
            count + 1,
            config.max_rate_limit_violations
        ))
        return false
    end
end

return _M 
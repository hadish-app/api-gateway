local _M = {}

local utils = require "utils"
local config = require "config"

-- Initialize shared dictionaries
local ip_blacklist = ngx.shared.ip_blacklist

-- Function to update banned_ips.conf with current bans
function _M.update_banned_ips_file()
    local keys = ip_blacklist:get_keys()
    local current_time = ngx.time()
    local active_bans = {}
    
    -- Collect active bans
    for _, ip in ipairs(keys) do
        local ban_until = ip_blacklist:get(ip)
        if ban_until and current_time < ban_until then
            active_bans[ip] = ban_until
        end
    end
    
    -- Update the file
    local f = io.open(config.ip_ban.file_path, "w")
    if f then
        f:write("# Banned IPs Configuration\n")
        f:write("# Format: IP_ADDRESS ban_until_timestamp\n")
        f:write("# Auto-generated - DO NOT EDIT\n")
        f:write(string.format("# Last Updated: %s\n\n", os.date("%Y-%m-%d %H:%M:%S", current_time)))
        
        if next(active_bans) then
            f:write("# Currently Banned IPs:\n")
            for ip, ban_until in pairs(active_bans) do
                f:write(string.format("# %s until %s (expires in %d seconds)\n",
                    ip,
                    os.date("%Y-%m-%d %H:%M:%S", ban_until),
                    ban_until - current_time
                ))
            end
            f:write("\n")
        else
            f:write("# No IPs currently banned\n\n")
        end
        
        f:write("geo $banned_ip {\n")
        f:write("    default 0;\n")
        for ip, _ in pairs(active_bans) do
            f:write(string.format("    %s 1;\n", ip))
        end
        f:write("}\n\n")
        
        f:write("map $banned_ip $banned_response {\n")
        f:write("    0 '';\n")
        f:write('    1 \'{"error": "IP temporarily banned due to excessive requests. Try again later."}\';\n')
        f:write("}\n")
        f:close()
        
        -- Force nginx to reload the configuration
        os.execute("nginx -s reload")
    else
        ngx.log(ngx.ERR, string.format("[%s] Failed to open %s for writing", utils.get_iso8601_timestamp(), config.ip_ban.file_path))
    end
end

-- Function to ban an IP
function _M.ban_ip(ip)
    local ban_until = ngx.time() + config.ip_ban.duration
    
    -- Store the ban information
    local success, err, forcible = ip_blacklist:set(ip, ban_until)
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
        config.ip_ban.duration
    ))
    
    -- Update banned IPs file
    _M.update_banned_ips_file()
end

-- Function to check if IP is banned
function _M.is_ip_banned(ip)
    local ban_until = ip_blacklist:get(ip)
    
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

-- Function to clean expired bans
function _M.clean_expired_bans()
    local keys = ip_blacklist:get_keys()
    local current_time = ngx.time()
    local had_expired = false
    
    for _, ip in ipairs(keys) do
        local ban_until = ip_blacklist:get(ip)
        if ban_until and current_time >= ban_until then
            ip_blacklist:delete(ip)
            had_expired = true
            ngx.log(ngx.WARN, string.format(
                "[%s] Security Event [BAN_EXPIRED] - IP: %s, Ban expired at %s",
                utils.get_iso8601_timestamp(),
                ip,
                os.date("%Y-%m-%d %H:%M:%S", current_time)
            ))
        end
    end
    
    -- Only update the file if we had expired bans
    if had_expired then
        _M.update_banned_ips_file()
    end
end

-- Handle IP ban check
function _M.handle_ip_ban_check()
    local ip = ngx.var.remote_addr
    if _M.is_ip_banned(ip) then
        ngx.var.violation_type = "BANNED_IP"
        ngx.var.details = "Request from banned IP"
        ngx.status = 403
        ngx.header.content_type = "application/json"
        ngx.say('{"error": "IP temporarily banned due to excessive requests. Try again later."}')
        return ngx.exit(403)
    end
end

return _M 
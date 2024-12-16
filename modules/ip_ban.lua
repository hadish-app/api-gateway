local _M = {}

local utils = require "utils"
local config = require "config"

-- Initialize shared dictionaries
local ip_blacklist = ngx.shared.ip_blacklist

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
    
    -- Create or update banned_ips.conf
    local f = io.open(config.ip_ban.file_path, "w")
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
        if config.ip_ban.duration < 60 then
            f:write(string.format('    1 \'{"error": "IP temporarily banned due to excessive requests. Try again in %d seconds."}\';\n', config.ip_ban.duration))
        else
            f:write(string.format('    1 \'{"error": "IP temporarily banned due to excessive requests. Try again in %d minutes."}\';\n', math.ceil(config.ip_ban.duration/60)))
        end
        f:write("}\n")
        f:close()
        -- Force nginx to reload the configuration
        os.execute("nginx -s reload")
    else
        ngx.log(ngx.ERR, string.format("[%s] Failed to open %s for writing", utils.get_iso8601_timestamp(), config.ip_ban.file_path))
    end
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
    
    for _, ip in ipairs(keys) do
        local ban_until = ip_blacklist:get(ip)
        if ban_until and current_time >= ban_until then
            ip_blacklist:delete(ip)
            ngx.log(ngx.WARN, string.format(
                "[%s] Security Event [BAN_EXPIRED] - IP: %s, Ban expired at %s",
                utils.get_iso8601_timestamp(),
                ip,
                os.date("%Y-%m-%d %H:%M:%S", current_time)
            ))
            
            -- Clear the banned_ips.conf file
            local f = io.open(config.ip_ban.file_path, "w")
            if f then
                f:write("# Banned IPs Configuration\n")
                f:write("# Format: deny IP_ADDRESS;\n\n")
                f:write("# Auto-generated - DO NOT EDIT\n")
                f:write(string.format("# Last Ban Expired: %s\n", os.date("%Y-%m-%d %H:%M:%S", current_time)))
                f:write("geo $banned_ip {\n")
                f:write("    default 0;\n")
                f:write("}\n\n")
                f:write("map $banned_ip $banned_response {\n")
                f:write("    0 '';\n")
                f:write('    1 \'{"error": "IP temporarily banned due to excessive requests. Try again later."}\';\n')
                f:write("}\n")
                f:close()
                -- Force nginx to reload the configuration
                os.execute("nginx -s reload")
            end
        end
    end
end

return _M 
local _M = {}

-- Initialize shared dictionaries
local ip_blacklist = ngx.shared.ip_blacklist

-- Function to update banned_ips.conf with current bans
local function update_banned_ips_file()
    local keys = ip_blacklist:get_keys()
    local current_time = ngx.time()
    local active_bans = {}
    local ban_file = os.getenv("BANNED_IPS_FILE") or "/etc/nginx/banned_ips.conf"
    
    -- Collect active bans
    for _, ip in ipairs(keys) do
        local ban_until = ip_blacklist:get(ip)
        if ban_until and current_time < ban_until then
            active_bans[ip] = ban_until
        end
    end
    
    -- Update the file
    local f = io.open(ban_file, "w")
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
        ngx.log(ngx.ERR, string.format("[%s] Failed to open %s for writing", os.date("%Y-%m-%dT%H:%M:%SZ"), ban_file))
    end
end

-- Function to ban an IP
local function ban_ip(ip)
    local ban_duration = tonumber(os.getenv("BAN_DURATION_SECONDS")) or 3600
    local ban_until = ngx.time() + ban_duration
    
    -- Store the ban information
    local success, err = ip_blacklist:set(ip, ban_until)
    if not success then
        ngx.log(ngx.ERR, string.format("[%s] Failed to ban IP %s: %s", 
            os.date("%Y-%m-%dT%H:%M:%SZ"),
            ip, 
            err or "unknown error"
        ))
        return
    end
    
    -- Log detailed ban information
    ngx.log(ngx.WARN, string.format(
        "[%s] Security Event [IP_BANNED] - IP: %s, Ban Start: %s, Ban Until: %s (duration: %d seconds)",
        os.date("%Y-%m-%dT%H:%M:%SZ"),
        ip,
        os.date("%Y-%m-%d %H:%M:%S", ngx.time()),
        os.date("%Y-%m-%d %H:%M:%S", ban_until),
        ban_duration
    ))
    
    -- Update banned IPs file
    update_banned_ips_file()
end

-- Function to check if IP is banned
local function is_ip_banned(ip)
    local ban_until = ip_blacklist:get(ip)
    
    if ban_until then
        local current_time = ngx.time()
        local remaining_time = ban_until - current_time
        
        if current_time < ban_until then
            ngx.log(ngx.WARN, string.format(
                "[%s] Security Event [BANNED_REQUEST_BLOCKED] - IP: %s, Ban expires in %d seconds",
                os.date("%Y-%m-%dT%H:%M:%SZ"),
                ip,
                remaining_time
            ))
            return true, remaining_time
        end
    end
    return false
end

-- Function to clean expired bans
local function clean_expired_bans()
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
                os.date("%Y-%m-%dT%H:%M:%SZ"),
                ip,
                os.date("%Y-%m-%d %H:%M:%S", current_time)
            ))
        end
    end
    
    -- Only update the file if we had expired bans
    if had_expired then
        update_banned_ips_file()
    end
end

-- Middleware execute function
function _M.execute(ctx)
    local ip = ngx.var.remote_addr
    local is_banned, remaining_time = is_ip_banned(ip)
    
    if is_banned then
        -- Store ban information in context
        ctx.error = {
            status = ngx.HTTP_FORBIDDEN,
            message = "IP temporarily banned due to excessive requests",
            details = {
                ip = ip,
                remaining_time = remaining_time
            }
        }
        return false
    end
    
    -- Clean expired bans periodically (1% chance per request)
    if math.random() < 0.01 then
        clean_expired_bans()
    end
    
    return true
end

-- Expose functions for testing and manual control
_M.ban_ip = ban_ip
_M.is_ip_banned = is_ip_banned
_M.clean_expired_bans = clean_expired_bans

return _M 
local _M = {}

-- Default values for configuration
local defaults = {
    -- Rate Limiting Configuration
    rate_limit = {
        requests_per_second = 10,
        burst = 5,
        violations_before_ban = 3,
        violation_expiry = 60  -- seconds
    },
    -- IP Ban Configuration
    ip_ban = {
        duration = 1800,  -- 30 minutes in seconds
        file_path = "/etc/nginx/banned_ips.conf"
    },
    -- Admin Service Configuration
    admin_service = {
        url = "http://localhost:3000"
    },
    -- Logging Configuration
    logging = {
        buffer_size = "4k",
        flush_interval = "1s"
    }
}

-- Function to get environment variable with type conversion
local function get_env(name, default_value, value_type)
    local value = os.getenv(name)
    if not value then
        return default_value
    end
    
    if value_type == "number" then
        value = tonumber(value)
        if not value then
            ngx.log(ngx.WARN, string.format("Invalid number format for %s, using default: %s", name, default_value))
            return default_value
        end
    elseif value_type == "boolean" then
        value = value:lower()
        if value == "true" or value == "1" then
            return true
        elseif value == "false" or value == "0" then
            return false
        else
            ngx.log(ngx.WARN, string.format("Invalid boolean format for %s, using default: %s", name, default_value))
            return default_value
        end
    end
    
    return value
end

-- Initialize configuration from environment variables
function _M.init()
    -- Rate Limiting Configuration
    _M.rate_limit = {
        requests_per_second = get_env("RATE_LIMIT_REQUESTS", defaults.rate_limit.requests_per_second, "number"),
        burst = get_env("RATE_LIMIT_BURST", defaults.rate_limit.burst, "number"),
        violations_before_ban = get_env("MAX_RATE_LIMIT_VIOLATIONS", defaults.rate_limit.violations_before_ban, "number"),
        violation_expiry = get_env("RATE_LIMIT_WINDOW", defaults.rate_limit.violation_expiry, "number")
    }

    -- IP Ban Configuration
    _M.ip_ban = {
        duration = get_env("BAN_DURATION_SECONDS", defaults.ip_ban.duration, "number"),
        file_path = get_env("BANNED_IPS_FILE", defaults.ip_ban.file_path, "string")
    }

    -- Admin Service Configuration
    _M.admin_service = {
        url = get_env("ADMIN_SERVICE_URL", defaults.admin_service.url, "string")
    }

    -- Logging Configuration
    _M.logging = {
        buffer_size = get_env("LOG_BUFFER_SIZE", defaults.logging.buffer_size, "string"),
        flush_interval = get_env("LOG_FLUSH_INTERVAL", defaults.logging.flush_interval, "string")
    }

    -- Log the configuration
    ngx.log(ngx.INFO, "Configuration initialized:")
    ngx.log(ngx.INFO, "Rate Limiting:")
    ngx.log(ngx.INFO, string.format("  - Requests per second: %d", _M.rate_limit.requests_per_second))
    ngx.log(ngx.INFO, string.format("  - Burst: %d", _M.rate_limit.burst))
    ngx.log(ngx.INFO, string.format("  - Violations before ban: %d", _M.rate_limit.violations_before_ban))
    ngx.log(ngx.INFO, string.format("  - Violation expiry: %d seconds", _M.rate_limit.violation_expiry))
    ngx.log(ngx.INFO, "IP Ban:")
    ngx.log(ngx.INFO, string.format("  - Duration: %d seconds", _M.ip_ban.duration))
    ngx.log(ngx.INFO, string.format("  - File path: %s", _M.ip_ban.file_path))
    ngx.log(ngx.INFO, "Admin Service:")
    ngx.log(ngx.INFO, string.format("  - URL: %s", _M.admin_service.url))
    ngx.log(ngx.INFO, "Logging:")
    ngx.log(ngx.INFO, string.format("  - Buffer size: %s", _M.logging.buffer_size))
    ngx.log(ngx.INFO, string.format("  - Flush interval: %s", _M.logging.flush_interval))
end

return _M 
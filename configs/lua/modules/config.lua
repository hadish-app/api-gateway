local _M = {}

-- Function to get environment variable with default value
local function get_env(name, default)
    local value = os.getenv(name)
    if not value or value == "" then
        ngx.log(ngx.WARN, string.format("Environment variable %s not set, using default: %s", name, default))
        return default
    end
    return value
end

-- Function to load configuration from environment variables
function _M.load_config()
    -- Worker Settings
    _M.worker_connections = tonumber(get_env("WORKER_CONNECTIONS", "1024"))

    -- Rate Limiting Settings
    _M.rate_limit_requests = tonumber(get_env("RATE_LIMIT_REQUESTS", "10"))
    _M.rate_limit_burst = tonumber(get_env("RATE_LIMIT_BURST", "5"))
    _M.rate_limit_window = tonumber(get_env("RATE_LIMIT_WINDOW", "60"))
    _M.max_rate_limit_violations = tonumber(get_env("MAX_RATE_LIMIT_VIOLATIONS", "3"))
    _M.rate_limit_memory = get_env("RATE_LIMIT_MEMORY", "10m")
    _M.rate_limit_count_memory = get_env("RATE_LIMIT_COUNT_MEMORY", "10m")

    -- IP Ban Settings
    _M.ban_duration_seconds = tonumber(get_env("BAN_DURATION_SECONDS", "1800"))
    _M.ip_blacklist_memory = get_env("IP_BLACKLIST_MEMORY", "10m")

    -- Client Settings
    _M.client_max_body_size = get_env("CLIENT_MAX_BODY_SIZE", "10M")
    _M.client_body_timeout = tonumber(get_env("CLIENT_BODY_TIMEOUT", "12"))
    _M.client_header_timeout = tonumber(get_env("CLIENT_HEADER_TIMEOUT", "12"))
    _M.client_body_buffer_size = get_env("CLIENT_BODY_BUFFER_SIZE", "16k")
    _M.client_header_buffer_size = get_env("CLIENT_HEADER_BUFFER_SIZE", "1k")
    _M.large_client_header_buffers = string.format("%s %s",
        get_env("LARGE_CLIENT_HEADER_BUFFERS_NUMBER", "2"),
        get_env("LARGE_CLIENT_HEADER_BUFFERS_SIZE", "1k"))

    -- Logging Settings
    _M.log_level = get_env("LOG_LEVEL", "warn")
    _M.log_buffer_size = get_env("LOG_BUFFER_SIZE", "4k")
    _M.log_flush_interval = get_env("LOG_FLUSH_INTERVAL", "1s")

    -- Proxy Settings
    _M.proxy_connect_timeout = get_env("PROXY_CONNECT_TIMEOUT", "60s")
    _M.proxy_send_timeout = get_env("PROXY_SEND_TIMEOUT", "60s")
    _M.proxy_read_timeout = get_env("PROXY_READ_TIMEOUT", "60s")

    -- Service URLs
    _M.admin_service_url = get_env("ADMIN_SERVICE_URL", "http://localhost:3000")

    return _M
end

return _M 
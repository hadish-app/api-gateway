local _M = {
    -- Origin validation constants
    MAX_ORIGIN_LENGTH = 2048,
    MAX_SUBDOMAIN_COUNT = 10,
    MAX_SUBDOMAIN_LENGTH = 63,
    FORBIDDEN_CHARS = "[<>\"'\\%[%]%(%){};]",
    CONTROL_CHARS = "[%z\1-\31\127-\255]",
    FORBIDDEN_PROTOCOLS = {
        "javascript:", "data:", "vbscript:", "file:",
        "about:", "blob:", "ftp:", "ws:", "wss:", 
        "gopher:", "chrome:", "chrome-extension:"
    },

    -- Default configuration
    DEFAULT_CONFIG = {
        allow_origins = {"*"},
        allow_methods = {"GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"},
        allow_headers = {"Content-Type", "Authorization", "X-Requested-With", "X-Request-ID"},
        expose_headers = {"X-Request-ID"},
        max_age = 3600,
        allow_credentials = false
    },

    -- Common headers that are always allowed
    COMMON_HEADERS = {
        host = true,
        ["user-agent"] = true,
        accept = true,
        ["accept-encoding"] = true,
        ["accept-language"] = true,
        origin = true,
        connection = true
    }
}

return _M 
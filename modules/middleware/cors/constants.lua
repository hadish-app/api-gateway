local env = require "modules.utils.env"
local cjson = require "cjson"

-- Load environment configuration
local config = env.load_all()

local cors_config = config.cors
-- Log CORS configuration
ngx.log(ngx.INFO, "[cors] Loading CORS configuration:")
ngx.log(ngx.INFO, "[cors] allow_origins: " .. (cors_config.allow_origins))
ngx.log(ngx.INFO, "[cors] allow_methods: " .. (cors_config.allow_methods))
ngx.log(ngx.INFO, "[cors] allow_headers: " .. (cors_config.allow_headers))
ngx.log(ngx.INFO, "[cors] expose_headers: " .. (cors_config.expose_headers))
ngx.log(ngx.INFO, "[cors] max_age: " .. (cors_config.max_age))
ngx.log(ngx.INFO, "[cors] allow_credentials: " .. tostring(cors_config.allow_credentials))
ngx.log(ngx.INFO, "[cors] validation_max_origin_length: " .. (cors_config.validation_max_origin_length))
ngx.log(ngx.INFO, "[cors] validation_max_subdomain_count: " .. (cors_config.validation_max_subdomain_count))
ngx.log(ngx.INFO, "[cors] validation_max_subdomain_length: " .. (cors_config.validation_max_subdomain_length))
ngx.log(ngx.INFO, "[cors] common_headers: " .. (cors_config.common_headers))

-- Helper function to split comma-separated string into array
local function split_csv(str)
    local result = {}
    if not str then return result end
    for value in str:gmatch("[^,]+") do
        result[#result + 1] = value:match("^%s*(.-)%s*$") -- trim whitespace
    end
    return result
end

-- Helper function to convert comma-separated headers to map
local function headers_to_map(headers_str)
    local result = {}
    if not headers_str then return result end
    for header in headers_str:gmatch("[^,]+") do
        result[header:match("^%s*(.-)%s*$"):lower()] = true
    end
    return result
end

local _M = {
    -- Origin validation constants
    MAX_ORIGIN_LENGTH = cors_config.validation_max_origin_length,
    MAX_SUBDOMAIN_COUNT = cors_config.validation_max_subdomain_count,
    MAX_SUBDOMAIN_LENGTH = cors_config.validation_max_subdomain_length,
    FORBIDDEN_CHARS = "[<>\"'\\%[%]%(%){};]",
    CONTROL_CHARS = "[%z\1-\31\127-\255]",
    FORBIDDEN_PROTOCOLS = {
        "javascript:", "data:", "vbscript:", "file:",
        "about:", "blob:", "ftp:", "ws:", "wss:", 
        "gopher:", "chrome:", "chrome-extension:"
    },

    -- Default configuration
    DEFAULT_CONFIG = {
        allow_origins = split_csv(cors_config.allow_origins),
        allow_methods = split_csv(cors_config.allow_methods),
        allow_headers = split_csv(cors_config.allow_headers),
        expose_headers = split_csv(cors_config.expose_headers) ,
        max_age = cors_config.max_age ,
        allow_credentials = cors_config.allow_credentials
    },

    -- Common headers that are always allowed
    COMMON_HEADERS = headers_to_map(cors_config.common_headers)
}

return _M 
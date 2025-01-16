local cjson = require "cjson"
local constants = require "modules.middleware.cors.constants"
local utils = require "modules.middleware.cors.utils"
local ngx = ngx

-- Cache for computed values
local cache = {
    allowed_headers_map = {},
    methods_str = nil,
    headers_str = nil,
    expose_headers_str = nil
}

local function validate_config(config)
    ngx.log(ngx.DEBUG, string.format("[cors] Config validation started - Validating against schema: %s", cjson.encode({
        allow_origins = "required non-empty array",
        allow_methods = "required non-empty array",
        allow_headers = "required array",
        allow_credentials = "optional boolean (incompatible with wildcard origin)",
        max_age = "optional number",
        expose_headers = "optional array"
    })))
    
    ngx.log(ngx.DEBUG, string.format("[cors] Config to validate: %s", cjson.encode(config)))
    
    if type(config.allow_origins) ~= "table" or #config.allow_origins == 0 then
        local err = "allow_origins must be a non-empty array"
        ngx.log(ngx.ERR, string.format("[cors] Config validation failed - allow_origins: got %s (type: %s, length: %s), expected: non-empty array", 
            type(config.allow_origins) == "table" and cjson.encode(config.allow_origins) or tostring(config.allow_origins),
            type(config.allow_origins),
            type(config.allow_origins) == "table" and #config.allow_origins or "n/a"
        ))
        return nil, err
    end
    
    if config.allow_credentials and config.allow_origins[1] == "*" then
        local err = "cannot use credentials with wildcard origin"
        ngx.log(ngx.ERR, string.format("[cors] Config validation failed - incompatible settings: allow_credentials=%s with allow_origins[1]=%s", 
            tostring(config.allow_credentials), 
            config.allow_origins[1]
        ))
        return nil, err
    end
    
    if type(config.allow_methods) ~= "table" or #config.allow_methods == 0 then
        local err = "allow_methods must be a non-empty array"
        ngx.log(ngx.ERR, string.format("[cors] Config validation failed - allow_methods: got %s (type: %s, length: %s), expected: non-empty array", 
            type(config.allow_methods) == "table" and cjson.encode(config.allow_methods) or tostring(config.allow_methods),
            type(config.allow_methods),
            type(config.allow_methods) == "table" and #config.allow_methods or "n/a"
        ))
        return nil, err
    end
    
    if type(config.allow_headers) ~= "table" then
        local err = "allow_headers must be an array"
        ngx.log(ngx.ERR, string.format("[cors] Config validation failed - allow_headers: got %s (type: %s), expected: array", 
            type(config.allow_headers) == "table" and cjson.encode(config.allow_headers) or tostring(config.allow_headers),
            type(config.allow_headers)
        ))
        return nil, err
    end
    
    ngx.log(ngx.DEBUG, "[cors] Config validation completed successfully - All schema requirements met")
    return config
end

local function update_cache(config)
    ngx.log(ngx.DEBUG, "[cors] Cache update started - Preparing lookup maps and string representations")
    
    -- Update header maps
    cache.allowed_headers_map = utils.prepare_headers_map(config.allow_headers)
    
    -- Cache string representations
    cache.methods_str = utils.array_to_string(config.allow_methods)
    cache.headers_str = utils.array_to_string(config.allow_headers)
    cache.expose_headers_str = utils.array_to_string(config.expose_headers)
    
    ngx.log(ngx.DEBUG, string.format("[cors] Cache update completed - Maps and strings prepared: methods=%s headers=%s expose_headers=%s allowed_headers_count=%d", 
        cache.methods_str, cache.headers_str, cache.expose_headers_str, utils.table_length(cache.allowed_headers_map)))
end

local _M = {}

-- Current active configuration
_M.current = utils.deep_clone(constants.DEFAULT_CONFIG)

function _M.configure(user_config)
    ngx.log(ngx.INFO, string.format("[cors] CORS configuration started - Current config: %s, New config: %s", 
        cjson.encode(_M.current),
        user_config and cjson.encode(user_config) or "using defaults"))
    
    local config_to_use = user_config or constants.DEFAULT_CONFIG
    
    -- Validate configuration
    local validated, err = validate_config(config_to_use)
    if not validated then
        error("Failed to validate CORS config: " .. err)
    end
    
    -- Update current configuration
    _M.current = utils.deep_clone(validated)
    
    -- Update cache
    update_cache(_M.current)
    
    ngx.log(ngx.INFO, string.format("[cors] CORS configuration completed - Changes applied: %s", 
        utils.diff_configs(_M.current, config_to_use)))
    return _M.current
end

-- Initialize cache with default config
ngx.log(ngx.INFO, "[cors] CORS initialization started - Loading default configuration from constants")
update_cache(constants.DEFAULT_CONFIG)
ngx.log(ngx.INFO, string.format("[cors] CORS initialization completed - Default config loaded: %s", cjson.encode(constants.DEFAULT_CONFIG)))

-- Export module
_M.cache = cache
_M.common_headers_map = constants.COMMON_HEADERS

return _M 
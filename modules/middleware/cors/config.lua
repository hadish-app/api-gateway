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

local function format_validation_schema()
    return {
        allow_origins = {
            type = "array",
            required = true,
            non_empty = true,
            description = "List of allowed origins",
            constraints = "Must be non-empty array. Use ['*'] for all origins"
        },
        allow_methods = {
            type = "array",
            required = true,
            non_empty = true,
            description = "List of allowed HTTP methods",
            constraints = "Must be non-empty array of valid HTTP methods"
        },
        allow_headers = {
            type = "array",
            required = true,
            description = "List of allowed request headers",
            constraints = "Must be array of header names"
        },
        allow_credentials = {
            type = "boolean",
            required = false,
            description = "Whether to allow credentials",
            constraints = "Cannot be true when allow_origins=['*']"
        },
        max_age = {
            type = "number",
            required = false,
            description = "Preflight cache duration",
            constraints = "Must be a positive number"
        },
        expose_headers = {
            type = "array",
            required = false,
            description = "Headers exposed to browser",
            constraints = "Must be array of header names"
        }
    }
end

local function format_schema_and_config(schema, config)
    local lines = {
        "Schema:",
        "  allow_origins:",
        string.format("    type: %s", schema.allow_origins.type),
        string.format("    required: %s", schema.allow_origins.required),
        string.format("    description: %s", schema.allow_origins.description),
        string.format("    constraints: %s", schema.allow_origins.constraints),
        "  allow_methods:",
        string.format("    type: %s", schema.allow_methods.type),
        string.format("    required: %s", schema.allow_methods.required),
        string.format("    description: %s", schema.allow_methods.description),
        string.format("    constraints: %s", schema.allow_methods.constraints),
        "  allow_headers:",
        string.format("    type: %s", schema.allow_headers.type),
        string.format("    required: %s", schema.allow_headers.required),
        string.format("    description: %s", schema.allow_headers.description),
        string.format("    constraints: %s", schema.allow_headers.constraints),
        "",
        "Config to validate:",
        string.format("  %s", cjson.encode(config))
    }
    return table.concat(lines, "\n")
end

local function validate_config(config)
    local schema = format_validation_schema()
    ngx.log(ngx.DEBUG, string.format("[cors] Config validation started | Schema: %s | Config: %s", 
        cjson.encode(schema), cjson.encode(config)))
    
    -- Validate allow_origins
    if type(config.allow_origins) ~= "table" or #config.allow_origins == 0 then
        local err = "allow_origins must be a non-empty array"
        ngx.log(ngx.ERR, string.format("[cors] Config validation failed | Field: allow_origins | Error: %s | Expected: %s | Got: type=%s, value=%s, length=%s", 
            err,
            schema.allow_origins.constraints,
            type(config.allow_origins),
            type(config.allow_origins) == "table" and cjson.encode(config.allow_origins) or tostring(config.allow_origins),
            type(config.allow_origins) == "table" and #config.allow_origins or "n/a"
        ))
        return nil, err
    end
    
    -- Validate credentials with wildcard origin
    if config.allow_credentials and config.allow_origins[1] == "*" then
        local err = "cannot use credentials with wildcard origin"
        ngx.log(ngx.ERR, string.format("[cors] Config validation failed | Field: allow_credentials | Error: %s | Constraint: %s | Got: allow_credentials=%s, allow_origins[1]=%s", 
            err,
            schema.allow_credentials.constraints,
            tostring(config.allow_credentials),
            config.allow_origins[1]
        ))
        return nil, err
    end
    
    -- Validate allow_methods
    if type(config.allow_methods) ~= "table" or #config.allow_methods == 0 then
        local err = "allow_methods must be a non-empty array"
        ngx.log(ngx.ERR, string.format("[cors] Config validation failed | Field: allow_methods | Error: %s | Expected: %s | Got: type=%s, value=%s, length=%s", 
            err,
            schema.allow_methods.constraints,
            type(config.allow_methods),
            type(config.allow_methods) == "table" and cjson.encode(config.allow_methods) or tostring(config.allow_methods),
            type(config.allow_methods) == "table" and #config.allow_methods or "n/a"
        ))
        return nil, err
    end
    
    -- Validate allow_headers
    if type(config.allow_headers) ~= "table" then
        local err = "allow_headers must be an array"
        ngx.log(ngx.ERR, string.format("[cors] Config validation failed | Field: allow_headers | Error: %s | Expected: %s | Got: type=%s, value=%s", 
            err,
            schema.allow_headers.constraints,
            type(config.allow_headers),
            type(config.allow_headers) == "table" and cjson.encode(config.allow_headers) or tostring(config.allow_headers)
        ))
        return nil, err
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Config validation completed | allow_origins=%s | allow_methods=%s | allow_headers=%s | allow_credentials=%s | max_age=%s | expose_headers=%s", 
        cjson.encode(config.allow_origins),
        cjson.encode(config.allow_methods),
        cjson.encode(config.allow_headers),
        tostring(config.allow_credentials),
        tostring(config.max_age),
        config.expose_headers and cjson.encode(config.expose_headers) or "nil"
    ))
    return config
end

local function update_cache(config)
    ngx.log(ngx.DEBUG, string.format("[cors] Cache update started | Config: %s", cjson.encode(config)))
    
    -- Update header maps
    cache.allowed_headers_map = utils.prepare_headers_map(config.allow_headers)
    
    -- Cache string representations
    cache.methods_str = utils.array_to_string(config.allow_methods)
    cache.headers_str = utils.array_to_string(config.allow_headers)
    cache.expose_headers_str = utils.array_to_string(config.expose_headers)
    
    ngx.log(ngx.DEBUG, string.format("[cors] Cache update completed | Methods=%s | Headers=%s | Expose_headers=%s | Headers_map=%s", 
        cache.methods_str or "nil",
        cache.headers_str or "nil",
        cache.expose_headers_str or "nil",
        cjson.encode(cache.allowed_headers_map)
    ))
end

local _M = {}

-- Current active configuration
_M.current = utils.deep_clone(constants.DEFAULT_CONFIG)

function _M.configure(user_config)
    ngx.log(ngx.INFO, string.format("[cors] CORS configuration started | Current=%s | New=%s", 
        cjson.encode(_M.current),
        user_config and cjson.encode(user_config) or "using defaults"
    ))
    
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
    
    -- Log changes
    local changes = utils.diff_configs(_M.current, config_to_use)
    ngx.log(ngx.INFO, string.format("[cors] CORS configuration completed | Status=Success | Changes=%s", changes))
    
    return _M.current
end

-- Initialize cache with default config
ngx.log(ngx.INFO, string.format("[cors] CORS initialization started | Source=Default configuration from constants | Config=%s", cjson.encode(constants.DEFAULT_CONFIG)))

update_cache(constants.DEFAULT_CONFIG)

ngx.log(ngx.INFO, string.format("[cors] CORS initialization completed | Status=Success | Active=%s | Cache=%s", 
    cjson.encode(_M.current),
    cjson.encode(cache)
))

-- Export module
_M.cache = cache
_M.common_headers_map = constants.COMMON_HEADERS

return _M 
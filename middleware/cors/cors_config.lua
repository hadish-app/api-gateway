local cjson = require "cjson"
local utils = require "middleware.cors.cors_utils"
local ngx = ngx
local cors_config_validator = require "middleware.cors.cors_config_validator"
local route_registry = require "modules.core.route_registry"

local _M = {
    global = {},
    routes = {}
}

-- Static global cors configs
-- These values are static and should not change due to security reasons
local static_global_cors_configs = {
    forbidden_chars = "[<>\"'\\%[%]%(%){};]",
    control_chars = "[%z\1-\31\127-\255]",
    forbidden_protocols = {
        "javascript:", "data:", "vbscript:", "file:",
        "about:", "blob:", "ftp:", "ws:", "wss:", 
        "gopher:", "chrome:", "chrome-extension:"
    }
}

-- Cache fields mapping for string values that need to be cached
local cache_fields = {
    allow_origins = "allow_origins_str",
    allow_methods = "allow_methods_str", 
    allow_headers = "allow_headers_str",
    expose_headers = "expose_headers_str",
    allow_protocols = "allow_protocols_str",
    common_headers = "common_headers_str"
}

-- Load default global config from config_cache shared dictionary
local function load_default_global_config()
    local section = "cors"
    local config_cache = ngx.shared.config_cache
    if not config_cache then
        error("Failed to access config_cache shared dictionary")
    end
    
    local json_str = config_cache:get(section)
    if not json_str then
        error("Configuration section not found in cache: " .. section)
    end
    
    local config, err = cjson.decode(json_str)
    if err then
        error("Failed to decode cached config: " .. err)
    end

    local global_config = {
        cache = {
            allow_origins_str = config.allow_origins,
            allow_methods_str = config.allow_methods,
            allow_headers_str = config.allow_headers,
            expose_headers_str = config.expose_headers,
            allow_protocols_str = config.allow_protocols,
            common_headers_str = config.common_headers,
        },
        allow_origins = utils.split_csv(config.allow_origins),
        allow_methods = utils.split_csv(config.allow_methods),
        allow_headers = utils.prepare_headers_map(utils.split_csv(config.allow_headers)),
        expose_headers = utils.split_csv(config.expose_headers),
        allow_protocols = utils.split_csv(config.allow_protocols),
        common_headers = utils.prepare_headers_map(utils.split_csv(config.common_headers)),
        max_age = config.max_age,
        allow_credentials = config.allow_credentials,
        max_origin_length = config.validation_max_origin_length,
        max_subdomain_count = config.validation_max_subdomain_count,
        max_subdomain_length = config.validation_max_subdomain_length,
        forbidden_chars = static_global_cors_configs.forbidden_chars,
        control_chars = static_global_cors_configs.control_chars,
        forbidden_protocols = static_global_cors_configs.forbidden_protocols
    }

    return global_config
end

-- Configures global CORS settings by merging default and custom configurations
-- @param custom_global_config (table|nil) Optional custom configuration to override defaults
-- @return table The final validated global configuration
function _M.configure_global(custom_global_config)
    -- Start configuration process and log debug message
    ngx.log(ngx.DEBUG, "[cors] Starting global CORS configuration...")
    
    -- Load default configuration from shared dictionary
    local default_global_config = load_default_global_config()
    ngx.log(ngx.DEBUG, "[cors] Default global config loaded: " .. cjson.encode(default_global_config))

    -- Initialize global config with defaults
    local global_config = default_global_config
    


    -- If custom config provided, merge it with defaults
    if custom_global_config then
        ngx.log(ngx.DEBUG, "[cors] Custom global config provided: " .. cjson.encode(custom_global_config))
        ngx.log(ngx.DEBUG, "[cors] Extending default global config with custom config")
        
        -- Cache reference to avoid repeated table lookups
        local config_cache = global_config.cache
        
        -- Iterate through custom config and override defaults
        for k, v in pairs(custom_global_config) do
            if v ~= nil then
                global_config[k] = v
                -- Update cache fields for string values that need to be cached
                local cache_field = cache_fields[k]
                if cache_field then
                    config_cache[cache_field] = table.concat(v, ",")
                end
                ngx.log(ngx.DEBUG, string.format("[cors] Added custom config %s=%s", k, tostring(v)))
            end
        end
        ngx.log(ngx.INFO, "[cors] global config extended with custom config: " .. cjson.encode(global_config))
    else
        -- Log when using defaults only
        ngx.log(ngx.INFO, "[cors] No custom config provided. Using default global config: " .. cjson.encode(global_config))
    end

    -- Validate the merged configuration
    ngx.log(ngx.DEBUG, "[cors] Validating configuration...")
    local validated, err = cors_config_validator.validate_config(global_config)
    if not validated then
        -- If validation fails, log error and throw exception
        ngx.log(ngx.ERR, "[cors] Configuration validation failed: " .. err)
        error("Failed to validate CORS config: " .. err)
    end
    ngx.log(ngx.DEBUG, "[cors] Configuration validation completed")
    
    -- Log differences between old and new configurations
    local changes = utils.diff_configs(_M.global, global_config)
    ngx.log(ngx.INFO, string.format("[cors] CORS configuration completed | Status=Success | Changes=%s", changes))
    
    -- Update module's global configuration with validated config
    ngx.log(ngx.DEBUG, "[cors] Updating current configuration")
    _M.global = global_config

    -- Log successful update and return new config
    ngx.log(ngx.INFO, "[cors] Global CORS configuration successfully updated")
    return _M.global
end

function _M.configure(custom_global_config)
    _M.configure_global(custom_global_config)
    local routes = route_registry.get_routes()
    for path, methods in pairs(routes) do
        for method, route_info in pairs(methods) do
            -- Merge global cors config with route_info.cors as route_cors_config
            local route_cors_config = utils.deep_clone(_M.global)
            
            for k, v in pairs(route_info.cors) do
                if v ~= nil then
                    route_cors_config[k] = v
                    -- Update cache fields for string values that need to be cached
                    local cache_field = cache_fields[k]
                    if cache_field then
                        route_cors_config.cache[cache_field] = table.concat(v, ",")
                    end
                    -- Convert headers to maps
                    if k == "common_headers" or k == "allow_headers" then
                        route_cors_config[k] = utils.prepare_headers_map(v)
                    else
                        route_cors_config[k] = v
                    end
                end
            end

            -- validate the route_cors_config
            local validated, err = cors_config_validator.validate_config(route_cors_config)
            if not validated then
                ngx.log(ngx.ERR, "[cors] Route cors config validation failed: " .. err)
                error("Failed to validate CORS config: " .. err)
            end
            
            -- add the route_cors_config to _M.routes[path][method]
            _M.routes[path] = _M.routes[path] or {}
            _M.routes[path][method] = route_cors_config
            
        end
    end
end

function _M.get_route_config(path, method)
    ngx.log(ngx.DEBUG, string.format("[cors] get_route_config: path=%s, method=%s", path, method))
    if not path or not method or not _M.routes[path] or not _M.routes[path][method] then
        ngx.log(ngx.DEBUG, string.format("[cors] get_route_config: returning global config: %s", cjson.encode(_M.global)))
        return _M.global
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] got_route_config: %s", cjson.encode(_M.routes[path][method])))

    return _M.routes[path][method]
end

return _M 
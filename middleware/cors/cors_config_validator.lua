local cjson = require "cjson"

local function format_validation_schema()
    return {
        allow_protocols = {
            type = "array",
            required = true,
            non_empty = true,
            description = "List of allowed protocols",
            constraints = "Must be non-empty array. Use ['*'] for all protocols"
        },
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
        "  allow_protocols:",
        string.format("    type: %s", schema.allow_protocols.type),
        string.format("    required: %s", schema.allow_protocols.required),
        string.format("    non_empty: %s", schema.allow_protocols.non_empty),
        string.format("    description: %s", schema.allow_protocols.description),
        string.format("    constraints: %s", schema.allow_protocols.constraints),
        "  allow_origins:",
        string.format("    type: %s", schema.allow_origins.type),
        string.format("    required: %s", schema.allow_origins.required),
        string.format("    non_empty: %s", schema.allow_origins.non_empty),
        string.format("    description: %s", schema.allow_origins.description),
        string.format("    constraints: %s", schema.allow_origins.constraints),
        "  allow_methods:",
        string.format("    type: %s", schema.allow_methods.type),
        string.format("    required: %s", schema.allow_methods.required),
        string.format("    non_empty: %s", schema.allow_methods.non_empty),
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
    
    -- Validate allow_protocols
    if type(config.allow_protocols) ~= "table" or #config.allow_protocols == 0 then
        local err = "allow_protocols must be a non-empty array"
        ngx.log(ngx.ERR, string.format("[cors] Config validation failed | Field: allow_protocols | Error: %s | Expected: %s | Got: type=%s, value=%s, length=%s", 
            err,
            schema.allow_protocols.constraints,
            type(config.allow_protocols),
            type(config.allow_protocols) == "table" and cjson.encode(config.allow_protocols) or tostring(config.allow_protocols),
            type(config.allow_protocols) == "table" and #config.allow_protocols or "n/a"
        ))
        return nil, err
    end
    
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
        cjson.encode(config.allow_protocols),
        cjson.encode(config.allow_origins),
        cjson.encode(config.allow_methods),
        cjson.encode(config.allow_headers),
        tostring(config.allow_credentials),
        tostring(config.max_age),
        config.expose_headers and cjson.encode(config.expose_headers) or "nil"
    ))
    return config
end

return {
    validate_config = validate_config,
    format_validation_schema = format_validation_schema,
    format_schema_and_config = format_schema_and_config
} 
local lyaml = require "lyaml"
local lfs = require "lfs"
local _M = {}

-- Helper function to convert OpenAPI CORS to registry CORS format
local function convert_cors_config(cors)
    ngx.log(ngx.DEBUG, "Converting CORS config: ", require("cjson").encode(cors or {}))
    
    if not cors then 
        ngx.log(ngx.DEBUG, "No CORS config provided, returning nil")
        return nil 
    end
    
    local converted = {
        allow_protocols = cors.allowProtocols,
        allow_methods = cors.allowMethods,
        allow_headers = cors.allowHeaders,
        allow_credentials = cors.allowCredentials,
        max_age = cors.maxAge,
        expose_headers = cors.exposeHeaders,
        allow_origins = cors.allowOrigins
    }
    
    ngx.log(ngx.DEBUG, "Converted CORS config: ", require("cjson").encode(converted))
    return converted
end

-- Convert OpenAPI spec to registry format
function _M.convert_to_registry(spec_path)
    ngx.log(ngx.DEBUG, "Converting spec file to registry format: ", spec_path)
    
    -- Read and parse YAML file
    local file = io.open(spec_path, "r")
    if not file then
        ngx.log(ngx.ERR, "Failed to open spec file: ", spec_path)
        return nil, "Failed to open spec file: " .. spec_path
    end
    
    ngx.log(ngx.DEBUG, "Successfully opened spec file: ", spec_path)
    
    local content = file:read("*all")
    file:close()
    
    -- TODO: Remove this log
    ngx.log(ngx.DEBUG, "Raw YAML content: ", content)
    
    local spec = lyaml.load(content)
    if not spec then
        ngx.log(ngx.ERR, "Failed to parse YAML content from: ", spec_path)
        return nil, "Failed to parse YAML content"
    end
    
    ngx.log(ngx.DEBUG, "Successfully parsed YAML content: ", require("cjson").encode(spec))
    
    -- Extract service info
    local service_info = spec["x-service-info"]
    if not service_info then
        ngx.log(ngx.ERR, "Missing x-service-info in spec: ", spec_path)
        return nil, "Missing x-service-info in spec"
    end
    
    ngx.log(ngx.DEBUG, "Found service info: ", require("cjson").encode(service_info))
    
    -- Initialize service configuration
    local service = {
        id = service_info.id,
        module = service_info.module,
        cors = convert_cors_config(service_info.cors),
        routes = {}
    }
    
    ngx.log(ngx.DEBUG, "Initialized service config: ", require("cjson").encode(service))
    
    -- Process routes
    ngx.log(ngx.DEBUG, "Processing routes from paths: ", require("cjson").encode(spec.paths or {}))
    
    for path, path_info in pairs(spec.paths or {}) do
        ngx.log(ngx.DEBUG, "Processing path: ", path)
        
        for method, operation in pairs(path_info) do
            ngx.log(ngx.DEBUG, "Processing method: ", method, " for path: ", path)
            
            if method:lower() ~= "parameters" then
                local route_info = operation["x-route-info"]
                if route_info then
                    ngx.log(ngx.DEBUG, "Found route info for ", method, " ", path, ": ", 
                        require("cjson").encode(route_info))
                    
                    local route = {
                        id = route_info.id,
                        path = path,
                        method = method:upper(),
                        handler = route_info.handler,
                    }
                    
                    -- Handle route-specific CORS
                    if operation.cors then
                        ngx.log(ngx.DEBUG, "Found route-specific CORS for ", route.id)
                        route.cors = {
                            id = operation.cors.id,
                            allow_origins = operation.cors.allowOrigins
                        }
                        ngx.log(ngx.DEBUG, "Route CORS config: ", require("cjson").encode(route.cors))
                    end
                    
                    ngx.log(ngx.DEBUG, "Adding route to service: ", require("cjson").encode(route))
                    table.insert(service.routes, route)
                else
                    ngx.log(ngx.DEBUG, "No route info found for ", method, " ", path, ", skipping")
                end
            else
                ngx.log(ngx.DEBUG, "Skipping parameters key for path: ", path)
            end
        end
    end
    
    ngx.log(ngx.DEBUG, "Completed service conversion: ", require("cjson").encode(service))
    return service
end

-- Helper function to recursively find spec files
local function find_spec_files(dir)
    ngx.log(ngx.DEBUG, "Scanning directory for spec files: ", dir)
    local files = {}
    
    for entry in lfs.dir(dir) do
        if entry ~= "." and entry ~= ".." then
            local path = dir .. "/" .. entry
            local attr = lfs.attributes(path)
            
            ngx.log(ngx.DEBUG, "Found entry: ", path, ", type: ", attr.mode)
            
            if attr.mode == "directory" then
                -- Recursively scan subdirectories
                local sub_files = find_spec_files(path)
                for _, file in ipairs(sub_files) do
                    table.insert(files, file)
                end
            elseif entry == "spec.yaml" then
                ngx.log(ngx.DEBUG, "Found spec file: ", path)
                table.insert(files, path)
            end
        end
    end
    
    return files
end

-- Load all service specs from a directory
function _M.load_services(specs_dir)
    ngx.log(ngx.DEBUG, "Loading service specs from directory: ", specs_dir)
    
    -- Check if directory exists
    local attr = lfs.attributes(specs_dir)
    if not attr or attr.mode ~= "directory" then
        ngx.log(ngx.ERR, "Invalid specs directory: ", specs_dir)
        return nil, "Invalid specs directory"
    end
    
    local services = {}
    local spec_files = find_spec_files(specs_dir)
    
    ngx.log(ngx.DEBUG, "Found spec files: ", require("cjson").encode(spec_files))
    
    for _, spec_path in ipairs(spec_files) do
        ngx.log(ngx.DEBUG, "Processing spec file: ", spec_path)
        
        local service, err = _M.convert_to_registry(spec_path)
        if service then
            ngx.log(ngx.DEBUG, "Successfully loaded service: ", service.id, 
                " from: ", spec_path)
            services[service.id] = service
        else
            ngx.log(ngx.ERR, "Failed to load spec: ", spec_path, 
                ", error: ", (err or "unknown"))
        end
    end
    
    ngx.log(ngx.DEBUG, "Completed loading all services: ", 
        require("cjson").encode(services))
    
    return services
end

return _M 
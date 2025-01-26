local cjson = require "cjson"
local lyaml = require "lyaml"
local lfs = require "lfs"
local _M = {}

-- Helper function to merge CORS configurations
local function merge_cors_configs(base_cors, override_cors)
    if not override_cors then return base_cors end
    if not base_cors then return override_cors end
    
    local merged = {}
    for k, v in pairs(base_cors) do
        merged[k] = v
    end
    
    -- Override with route-specific settings
    local converted_override = override_cors
    for k, v in pairs(converted_override or {}) do
        merged[k] = v
    end
    
    return merged
end

-- Helper function to recursively find spec files
local function find_spec_files(dir)
    ngx.log(ngx.DEBUG, "[Spec Loader] Scanning directory for spec files: ", dir)
    local files = {}
    
    for entry in lfs.dir(dir) do
        if entry ~= "." and entry ~= ".." then
            local path = dir .. "/" .. entry
            local attr = lfs.attributes(path)
            
            ngx.log(ngx.DEBUG, "[Spec Loader] Found entry: ", path, ", type: ", attr.mode)
            
            if attr.mode == "directory" then
                -- Recursively scan subdirectories
                local sub_files = find_spec_files(path)
                for _, file in ipairs(sub_files) do
                    table.insert(files, file)
                end
            elseif entry == "spec.yaml" then
                ngx.log(ngx.DEBUG, "[Spec Loader] Found spec file: ", path)
                table.insert(files, path)
            end
        end
    end
    
    return files
end

-- Convert OpenAPI spec to registry format
function _M.convert_to_registry(spec_path)
    ngx.log(ngx.DEBUG, "[Spec Loader] Converting spec file to registry format: ", spec_path)
    
    -- Read and parse YAML file
    local file = io.open(spec_path, "r")
    if not file then
        ngx.log(ngx.ERR, "[Spec Loader] Failed to open spec file: ", spec_path)
        return nil, "Failed to open spec file: " .. spec_path
    end
    
    ngx.log(ngx.DEBUG, "[Spec Loader] Successfully opened spec file: ", spec_path)
    
    local content = file:read("*all")
    file:close()
    
    local spec = lyaml.load(content)
    if not spec then
        ngx.log(ngx.ERR, "[Spec Loader] Failed to parse YAML content from: ", spec_path)
        return nil, "Failed to parse YAML content"
    end
    
    ngx.log(ngx.DEBUG, "[Spec Loader] Successfully parsed YAML content: ", cjson.encode(spec))
    
    -- Extract service info
    local service_info = spec["x-service-info"]
    if not service_info then
        ngx.log(ngx.ERR, "[Spec Loader] Missing x-service-info in spec: ", spec_path)
        return nil, "Missing x-service-info in spec"
    end
    
    ngx.log(ngx.DEBUG, "[Spec Loader] Found service info: ", cjson.encode(service_info))
    
    -- Initialize service configuration
    local service = {
        id = service_info.id,
        module = service_info.module,
        cors = service_info.cors,
        routes = {}
    }
    
    ngx.log(ngx.DEBUG, "[Spec Loader] Initialized service config: ", cjson.encode(service))
    
    -- Process routes
    ngx.log(ngx.DEBUG, "[Spec Loader] Processing routes from paths: ", cjson.encode(spec.paths or {}))
    
    for path, path_info in pairs(spec.paths or {}) do
        ngx.log(ngx.DEBUG, "[Spec Loader] Processing path: ", path)
        
        for method, operation in pairs(path_info) do
            ngx.log(ngx.DEBUG, "[Spec Loader] Processing method: ", method, " for path: ", path)
            
            if method:lower() ~= "parameters" then
                local route_info = operation["x-route-info"]
                if route_info then
                    ngx.log(ngx.DEBUG, "[Spec Loader] Found route info for ", method, " ", path, ": ", 
                        cjson.encode(route_info))
                    
                    local route = {
                        id = route_info.id,
                        path = path,
                        method = method:upper(),
                        handler = route_info.handler,
                    }
                    
                    -- Handle route-specific CORS
                    if operation.cors then
                        ngx.log(ngx.DEBUG, "[Spec Loader] Found route-specific CORS for ", route.id)
                        route.cors = merge_cors_configs(service.cors, operation.cors)
                        ngx.log(ngx.DEBUG, "[Spec Loader] Merged route CORS config: ", cjson.encode(route.cors))
                    end
                    
                    ngx.log(ngx.DEBUG, "[Spec Loader] Adding route to service: ", cjson.encode(route))
                    table.insert(service.routes, route)
                else
                    ngx.log(ngx.DEBUG, "[Spec Loader] No route info found for ", method, " ", path, ", skipping")
                end
            else
                ngx.log(ngx.DEBUG, "[Spec Loader] Skipping parameters key for path: ", path)
            end
        end
    end
    
    ngx.log(ngx.DEBUG, "[Spec Loader] Completed service conversion: ", cjson.encode(service))
    return service
end

-- Load all service specs from a directory
function _M.load_services(specs_dir)
    ngx.log(ngx.DEBUG, "[Spec Loader] Loading service specs from directory: ", specs_dir)
    
    -- Check if directory exists
    local attr = lfs.attributes(specs_dir)
    if not attr or attr.mode ~= "directory" then
        ngx.log(ngx.ERR, "[Spec Loader] Invalid specs directory: ", specs_dir)
        return nil, "Invalid specs directory"
    end
    
    local services = {}
    local spec_files = find_spec_files(specs_dir)
    
    ngx.log(ngx.DEBUG, "[Spec Loader] Found spec files: ", cjson.encode(spec_files))
    
    for _, spec_path in ipairs(spec_files) do
        ngx.log(ngx.DEBUG, "[Spec Loader] Processing spec file: ", spec_path)
        
        local service, err = _M.convert_to_registry(spec_path)
        if service then
            ngx.log(ngx.DEBUG, "[Spec Loader] Successfully loaded service: ", service.id, 
                " from: ", spec_path)
            services[service.id] = service
        else
            ngx.log(ngx.ERR, "[Spec Loader] Failed to load spec: ", spec_path, 
                ", error: ", (err or "unknown"))
        end
    end
    
    ngx.log(ngx.DEBUG, "[Spec Loader] Completed loading all services: ", 
        cjson.encode(services))
    
    return services
end

return _M 
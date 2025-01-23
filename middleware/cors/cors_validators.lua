local config = require "middleware.cors.cors_config"
local constants = require "middleware.cors.cors_constants"
local utils = require "middleware.cors.cors_utils"
local ngx = ngx

local function get_request_context()
    return string.format(
        "client=%s request_id=%s method=%s uri=%s",
        ngx.var.remote_addr,
        ngx.ctx.request_id or "none",
        ngx.req.get_method(),
        ngx.var.request_uri
    )
end

-- Basic validation checks
local function validate_origin_basics(origin, allowed_origins)
    local ctx = get_request_context()
    ngx.log(ngx.DEBUG, string.format("[cors] Origin basic validation started. origin=%s. %s", origin, ctx))
    
    if type(origin) ~= "string" or type(allowed_origins) ~= "table" or
       not origin or origin == "null" or #origin > constants.MAX_ORIGIN_LENGTH then
        ngx.log(ngx.WARN, string.format("[cors] Origin basic validation failed. origin=%s length=%s. %s", 
            origin or "nil", origin and #origin or 0, ctx))
        return false
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Origin basic validation completed. %s", ctx))
    return true
end

-- Check for dangerous characters
local function check_dangerous_characters(origin)
    local ctx = get_request_context()
    ngx.log(ngx.DEBUG, string.format("[cors] Origin character validation started. origin=%s. %s", origin, ctx))
    
    if origin:find(constants.CONTROL_CHARS) then
        ngx.log(ngx.WARN, string.format("[cors] Origin character validation failed - control chars found. origin=%s. %s", origin, ctx))
        return false
    end
    
    if origin:find(constants.FORBIDDEN_CHARS) then
        ngx.log(ngx.WARN, string.format("[cors] Origin character validation failed - forbidden chars found. origin=%s. %s", origin, ctx))
        return false
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Origin character validation completed. %s", ctx))
    return true
end

-- Check for allowed protocols
local function check_allowed_protocols(origin)
    local ctx = get_request_context()
    ngx.log(ngx.DEBUG, string.format("[cors] Origin protocol validation started. origin=%s. %s", origin, ctx))
    
    local lower_origin = origin:lower()
    for _, protocol in ipairs(constants.ALLOW_PROTOCOLS) do
        if lower_origin:find(protocol, 1, true) then
            ngx.log(ngx.DEBUG, string.format("[cors] Origin protocol validation completed. %s", ctx))
            return true
        end
    end
end

-- Check for forbidden protocols
local function check_forbidden_protocols(origin)
    local ctx = get_request_context()
    ngx.log(ngx.DEBUG, string.format("[cors] Origin protocol validation started. origin=%s. %s", origin, ctx))
    
    local lower_origin = origin:lower()
    for _, protocol in ipairs(constants.FORBIDDEN_PROTOCOLS) do
        if lower_origin:find(protocol, 1, true) then
            ngx.log(ngx.WARN, string.format("[cors] Origin protocol validation failed - forbidden protocol found: %s. origin=%s. %s", 
                protocol, origin, ctx))
            return false
        end
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Origin protocol validation completed. %s", ctx))
    return true
end

-- Validate protocol and domain format
local function validate_protocol_and_domain(origin)
    local ctx = get_request_context()
    ngx.log(ngx.DEBUG, string.format("[cors] Origin URL validation started. origin=%s. %s", origin, ctx))
    
    local protocol, domain = origin:match("^(https?)://([^/]+)$")
    if not protocol or not domain then
        ngx.log(ngx.WARN, string.format("[cors] Origin URL validation failed - invalid format. origin=%s. %s", origin, ctx))
        return false, nil
    end
    
    if not check_allowed_protocols(protocol) then
        ngx.log(ngx.WARN, string.format("[cors] Origin URL validation failed - non-allowed protocol. protocol=%s origin=%s. %s", 
            protocol, origin, ctx))
        return false, nil
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Origin URL validation completed. %s", ctx))
    return true, domain
end

-- Validate domain part
local function validate_domain_part(part)
    local ctx = get_request_context()
    ngx.log(ngx.DEBUG, string.format("[cors] Domain part validation started: %s. %s", part, ctx))
    
    if #part > constants.MAX_SUBDOMAIN_LENGTH then
        ngx.log(ngx.WARN, string.format("[cors] Domain part validation failed - exceeds max length. part=%s length=%d max=%d. %s", 
            part, #part, constants.MAX_SUBDOMAIN_LENGTH, ctx))
        return false
    end
    
    local is_valid
    if #part == 1 then
        is_valid = part:match("^%w$") ~= nil
    else
        is_valid = part:match("^[%w][-_%w]*[%w]$") and not part:find("%-%-")
    end
    
    if not is_valid then
        ngx.log(ngx.WARN, string.format("[cors] Domain part validation failed - invalid format. part=%s. %s", part, ctx))
    else
        ngx.log(ngx.DEBUG, string.format("[cors] Domain part validation completed. %s", ctx))
    end
    
    return is_valid
end

-- Validate domain structure
local function validate_domain_structure(domain)
    local ctx = get_request_context()
    ngx.log(ngx.DEBUG, string.format("[cors] Domain structure validation started. domain=%s. %s", domain, ctx))
    
    local parts = {}
    for part in domain:gmatch("[^%.]+") do
        table.insert(parts, part)
    end
    
    if #parts > constants.MAX_SUBDOMAIN_COUNT then
        ngx.log(ngx.WARN, string.format("[cors] Domain structure validation failed - too many subdomains. count=%d max=%d domain=%s. %s", 
            #parts, constants.MAX_SUBDOMAIN_COUNT, domain, ctx))
        return false
    end
    
    for _, part in ipairs(parts) do
        if not validate_domain_part(part) then
            return false
        end
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Domain structure validation completed. %s", ctx))
    return true
end

-- Check against allowed origins
local function check_allowed_origins(origin, allowed_origins)
    local ctx = get_request_context()
    ngx.log(ngx.DEBUG, string.format("[cors] Allowed origins validation started. origin=%s. %s", origin, ctx))
    
    if allowed_origins[1] == "*" then
        ngx.log(ngx.DEBUG, string.format("[cors] Allowed origins validation completed - wildcard allowed. %s", ctx))
        return true
    end
    
    for _, allowed in ipairs(allowed_origins) do
        ngx.log(ngx.DEBUG, string.format("[cors] Allowed origins matching: %s origin=%s", allowed, origin))
        if type(allowed) == "string" and 
           #allowed <= constants.MAX_ORIGIN_LENGTH and
           allowed == origin then
            ngx.log(ngx.DEBUG, string.format("[cors] Allowed origins validation completed - match found. %s", ctx))
            return true
        end
    end
    
    ngx.log(ngx.WARN, string.format("[cors] Allowed origins validation failed - no match found. origin=%s. %s", origin, ctx))
    return false
end

local function is_origin_allowed(origin, allowed_origins)
    local ctx = get_request_context()
    ngx.log(ngx.DEBUG, string.format("[cors] Origin validation chain started. origin=%s. %s", origin, ctx))
    
    -- Run all validation checks in sequence
    if not validate_origin_basics(origin, allowed_origins) then
        return false
    end
    
    if not check_dangerous_characters(origin) then
        return false
    end
    
    if not check_forbidden_protocols(origin) then
        return false
    end
    
    local valid_protocol, domain = validate_protocol_and_domain(origin)
    if not valid_protocol then
        return false
    end
    
    if not validate_domain_structure(domain) then
        return false
    end
    
    local allowed = check_allowed_origins(origin, allowed_origins)
    if allowed then
        ngx.log(ngx.DEBUG, string.format("[cors] Origin validation chain completed successfully. origin=%s. %s", origin, ctx))
    end
    
    return allowed
end

return {
    is_origin_allowed = is_origin_allowed,
    sanitize_header = utils.sanitize_header,
    format_cors_error = utils.format_cors_error
} 
local cjson = require "cjson"
local config = require "middleware.cors.cors_config"
local utils = require "middleware.cors.cors_utils"
local ngx = ngx

-- Helper function to get request context for logging
local function get_request_context()
    return string.format(
        "client=%s request_id=%s method=%s uri=%s",
        ngx.var.remote_addr,
        ngx.ctx.request_id or "none", 
        ngx.req.get_method(),
        ngx.var.request_uri
    )
end

-- Remove log_debug and log_warn functions and update validator functions
local validators = {
    validate_origin_format = function(cors_ctx)
        ngx.log(ngx.DEBUG, string.format("[cors] Origin format validation started. origin=%s. %s", cors_ctx.origin, cors_ctx.log_context))
        
        local origin = cors_ctx.origin
        local max_length = cors_ctx.config.max_origin_length
        ngx.log(ngx.DEBUG, string.format("[cors] config.global: %s", cjson.encode(config.global)))
        
        if not origin or 
           origin == "" or
           origin == "null" or 
           #origin > max_length or 
           type(origin) ~= "string" or 
           type(cors_ctx.config.allow_origins) ~= "table" then
            
            local reason
            if not origin then
                reason = "origin is nil"
            elseif origin == "" then
                reason = "origin is empty string"
            elseif origin == "null" then
                reason = "origin is 'null'"
            elseif #origin > max_length then
                reason = string.format("origin length %d exceeds max length %d", #origin, max_length)
            elseif type(origin) ~= "string" then
                reason = string.format("origin type is %s, expected string", type(origin))
            else
                reason = "allowed_origins configuration invalid"
            end
            
            ngx.log(ngx.WARN, string.format("[cors] Origin format validation failed - %s. origin=%s length=%s. %s",
                reason, origin or "nil", origin and #origin or 0, cors_ctx.log_context))
            return false
        end
        
        ngx.log(ngx.DEBUG, string.format("[cors] Origin format validation completed. %s", cors_ctx.log_context))
        return true
    end,

    validate_characters = function(cors_ctx)
        ngx.log(ngx.DEBUG, string.format("[cors] Origin character validation started. origin=%s. %s", cors_ctx.origin, cors_ctx.log_context))
        
        if string.find(cors_ctx.origin, config.global.control_chars) or 
           string.find(cors_ctx.origin, config.global.forbidden_chars) then
            ngx.log(ngx.WARN, string.format("[cors] Origin character validation failed. origin=%s. %s", cors_ctx.origin, cors_ctx.log_context))
            return false
        end
        
        ngx.log(ngx.DEBUG, string.format("[cors] Origin character validation completed. %s", cors_ctx.log_context))
        return true
    end,

    validate_protocol = function(cors_ctx)
        ngx.log(ngx.DEBUG, string.format("[cors] Origin protocol validation started. origin=%s. %s", cors_ctx.origin, cors_ctx.log_context))
        
        local lower_origin = string.lower(cors_ctx.origin)
        
        -- Check forbidden protocols first
        for _, protocol in ipairs(config.global.forbidden_protocols) do
            if string.find(lower_origin, protocol, 1, true) then
                ngx.log(ngx.WARN, string.format("[cors] Origin protocol validation failed - forbidden protocol: %s. origin=%s. %s", 
                    protocol, cors_ctx.origin, cors_ctx.log_context))
                return false
            end
        end
        
        -- Check allowed protocols
        for _, protocol in ipairs(config.global.allow_protocols) do
            if string.find(lower_origin, protocol, 1, true) then
                ngx.log(ngx.DEBUG, string.format("[cors] Origin protocol validation completed. %s", cors_ctx.log_context))
                return true
            end
        end
        
        ngx.log(ngx.WARN, string.format("[cors] Origin protocol validation failed - no allowed protocol found. origin=%s. %s", 
            cors_ctx.origin, cors_ctx.log_context))
        return false
    end,

    validate_domain = function(cors_ctx)
        ngx.log(ngx.DEBUG, string.format("[cors] Domain validation started. origin=%s. %s", cors_ctx.origin, cors_ctx.log_context))
        
        -- Validate URL format and protocol
        local protocol, domain = string.match(cors_ctx.origin, "^(https?)://([^/]+)$")
        if not protocol or not domain then
            ngx.log(ngx.WARN, string.format("[cors] Domain validation failed - invalid format. origin=%s. %s", 
                cors_ctx.origin, cors_ctx.log_context))
            return false
        end
        
        -- Split domain into parts and validate count
        local parts = {}
        for part in domain:gmatch("[^%.]+") do
            table.insert(parts, part)
        end
        
        if #parts > config.global.max_subdomain_count then
            ngx.log(ngx.WARN, string.format("[cors] Domain validation failed - too many subdomains. count=%d domain=%s. %s", 
                #parts, domain, cors_ctx.log_context))
            return false
        end
        
        -- Validate each domain part
        for _, part in ipairs(parts) do
            if #part > config.global.max_subdomain_length then
                ngx.log(ngx.WARN, string.format("[cors] Domain part validation failed - length. part=%s length=%d. %s", 
                    part, #part, cors_ctx.log_context))
                return false
            end
            
            local is_valid = (#part == 1 and part:match("^%w$")) or
                           (#part > 1 and part:match("^[%w][-_%w]*[%w]$") and not string.find(part, "%-%-"))
            
            if not is_valid then
                ngx.log(ngx.WARN, string.format("[cors] Domain part validation failed - format. part=%s. %s", 
                    part, cors_ctx.log_context))
                return false
            end
        end
        
        ngx.log(ngx.DEBUG, string.format("[cors] Domain validation completed. %s", cors_ctx.log_context))
        return true
    end,

    validate_allowed_origins = function(cors_ctx)
        ngx.log(ngx.DEBUG, string.format("[cors] Allowed origins validation started. origin=%s. %s", 
            cors_ctx.origin, cors_ctx.log_context))
        
        if cors_ctx.config.allow_origins[1] == "*" then
            ngx.log(ngx.DEBUG, string.format("[cors] Allowed origins validation completed - wildcard allowed. %s", 
                cors_ctx.log_context))
            return true
        end
        
        for _, allowed in ipairs(cors_ctx.config.allow_origins) do
            if type(allowed) == "string" and 
               #allowed <= config.global.max_origin_length and
               allowed == cors_ctx.origin then
                ngx.log(ngx.DEBUG, string.format("[cors] Allowed origins validation completed - match found. %s", 
                    cors_ctx.log_context))
                return true
            end
        end
        
        ngx.log(ngx.WARN, string.format("[cors] Allowed origins validation failed - no match. origin=%s. %s", 
            cors_ctx.origin, cors_ctx.log_context))
        return false
    end
}

-- Main validation function
local function is_origin_allowed(cors_ctx)
    ngx.log(ngx.DEBUG, string.format("[cors] Origin validation chain started. origin=%s. %s", 
        cors_ctx.origin, cors_ctx.log_context))
    
    -- Run validation chain
    if not validators.validate_origin_format(cors_ctx) or
       not validators.validate_characters(cors_ctx) or
       not validators.validate_protocol(cors_ctx) or
       not validators.validate_domain(cors_ctx) or
       not validators.validate_allowed_origins(cors_ctx) then
        return false
    end
    
    ngx.log(ngx.DEBUG, string.format("[cors] Origin validation chain completed successfully. origin=%s. %s", 
        cors_ctx.origin, cors_ctx.log_context))
    return true
end

return {
    is_origin_allowed = is_origin_allowed,
    sanitize_header = utils.sanitize_header,
    format_cors_error = utils.format_cors_error
}
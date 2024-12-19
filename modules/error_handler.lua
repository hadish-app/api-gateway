local _M = {}
local cjson = require "cjson"

-- List of suspicious patterns that should trigger security logging
local suspicious_patterns = {
    "%.php",
    "%.asp",
    "wp%-",
    "wordpress",
    "phpmyadmin",
    "admin",
    "%.git",
    "%.env",
    "%.conf",
    "%.sql",
    "%.bak",
    "%.zip",
    "%.tar",
    "%.gz",
    "eval",
    "exec",
    "select.*from",
    "union.*select",
    "information_schema"
}

-- Check if the request URI contains suspicious patterns
local function is_suspicious_request(uri)
    uri = uri:lower()
    for _, pattern in ipairs(suspicious_patterns) do
        if uri:find(pattern) then
            return true
        end
    end
    return false
end

-- Log the request details
local function log_request(uri, is_suspicious)
    if is_suspicious then
        -- Set variables for security log only
        ngx.var.violation_type = "SUSPICIOUS_404"
        ngx.var.details = string.format(
            "Suspicious pattern detected in request path: %s",
            uri
        )
    else
        -- Clear security log variables for normal 404s
        ngx.var.violation_type = ""
        ngx.var.details = ""
    end
end

-- Standard error response
local function send_error_response(status, message)
    ngx.status = status
    ngx.header.content_type = "application/json"
    
    -- Generic error response that doesn't leak information
    local error_response = {
        status = status,
        error = status == 404 and "Not Found" or "Forbidden",
        message = message,
        request_id = ngx.var.request_id
    }
    
    ngx.say(cjson.encode(error_response))
    return ngx.exit(status)
end

function _M.handle_not_found()
    local uri = ngx.var.request_uri
    local is_suspicious = is_suspicious_request(uri)
    
    -- Log the request (access log handles normal logging)
    log_request(uri, is_suspicious)
    
    -- Always use the same generic message for 404s
    return send_error_response(404, "The requested resource could not be found")
end

function _M.handle_forbidden()
    -- Set security log variables
    ngx.var.violation_type = "FORBIDDEN_ACCESS"
    ngx.var.details = string.format(
        "Forbidden access attempt: %s",
        ngx.var.request_uri
    )
    
    return send_error_response(403, "Access to this resource is forbidden")
end

return _M 
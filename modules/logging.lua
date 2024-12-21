local _M = {}

-- Log format definitions
_M.log_formats = {
    main_ext = [[escape=json '[$timestamp] "$remote_addr" - "$remote_user" '
                '"$request" "$status" "$body_bytes_sent" '
                '"$http_referer" "$http_user_agent" '
                '"forwarded_for":"$http_x_forwarded_for" '
                '"req_time":"$request_time" '
                '"upstream_time":"$upstream_response_time" '
                '"upstream_status":"$upstream_status" '
                '"host":"$host" '
                '"server_port":"$server_port" '
                '"request_id":"$request_id"']],
                
    security = [[escape=json '[$timestamp] "$remote_addr" '
                '"client":"$http_user_agent" '
                '"forwarded_for":"$http_x_forwarded_for" '
                '"request":"$request" '
                '"status":"$status" '
                '"violation_type":"$violation_type" '
                '"details":"$details" '
                '"request_id":"$request_id"']]
}

-- Time format maps
_M.time_maps = {
    millisec = {
        pattern = "~^(?<sec>\\d+)\\.(?<ms>\\d+)$",
        template = "$ms"
    },
    timestamp = {
        pattern = "~^(?<dt>\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2})\\+(?<tz>\\d{2}:\\d{2})$",
        template = "$dt.$millisec+$tz"
    }
}

-- Logging control maps
_M.control_maps = {
    status_requires_security_log = {
        ["~^[45]"] = 1,        -- Log all 4xx and 5xx errors
        ["default"] = 0
    },
    has_security_violation = {
        [""] = 0,              -- No security logging for empty violation type
        ["default"] = 1        -- Log when violation type is set
    },
    log_security = {
        ["~1"] = 1,           -- Log if either condition is true
        ["default"] = 0
    }
}

-- Get log buffer configuration
function _M.get_log_buffer_config()
    return {
        buffer_size = "4k",
        flush_interval = "1s"
    }
end

return _M 
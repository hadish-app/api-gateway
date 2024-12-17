#!/bin/bash

# Import test utilities
source "$(dirname "$0")/../test_utils.sh"

# Load environment variables
load_env

# Test environment variables
test_environment_variables() {
    print_header "Testing Environment Variables"
    local missing_vars=0
    
    # Required variables array
    local required_vars=(
        "API_GATEWAY_PORT"
        "ADMIN_SERVICE_URL"
        "RATE_LIMIT_REQUESTS"
        "RATE_LIMIT_BURST"
        "RATE_LIMIT_WINDOW"
        "MAX_RATE_LIMIT_VIOLATIONS"
        "BAN_DURATION_SECONDS"
        "BANNED_IPS_FILE"
        "LOG_LEVEL"
        "LOG_BUFFER_SIZE"
        "LOG_FLUSH_INTERVAL"
    )
    
    # Check each required variable
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            print_error "Missing required variable: $var"
            missing_vars=$((missing_vars + 1))
        else
            print_success "Found $var = ${!var}"
        fi
    done
    
    # Validate numeric values
    local numeric_vars=(
        "API_GATEWAY_PORT"
        "RATE_LIMIT_REQUESTS"
        "RATE_LIMIT_BURST"
        "RATE_LIMIT_WINDOW"
        "MAX_RATE_LIMIT_VIOLATIONS"
        "BAN_DURATION_SECONDS"
    )
    
    for var in "${numeric_vars[@]}"; do
        if [[ "${!var}" =~ ^[0-9]+$ ]]; then
            print_success "$var is numeric: ${!var}"
        else
            print_error "$var should be numeric, got: ${!var}"
            missing_vars=$((missing_vars + 1))
        fi
    done
    
    return $missing_vars
}

# Test file permissions and existence
test_file_permissions() {
    print_header "Testing File Permissions and Existence"
    local errors=0
    
    # Test nginx.conf
    if docker exec api-gateway test -f /usr/local/openresty/nginx/conf/nginx.conf; then
        print_success "nginx.conf exists"
        if docker exec api-gateway test -r /usr/local/openresty/nginx/conf/nginx.conf; then
            print_success "nginx.conf is readable"
        else
            print_error "nginx.conf is not readable"
            errors=$((errors + 1))
        fi
    else
        print_error "nginx.conf does not exist"
        errors=$((errors + 1))
    fi
    
    # Test log directory
    if docker exec api-gateway test -d /var/log/nginx; then
        print_success "Log directory exists"
        if docker exec api-gateway test -w /var/log/nginx; then
            print_success "Log directory is writable"
        else
            print_error "Log directory is not writable"
            errors=$((errors + 1))
        fi
    else
        print_error "Log directory does not exist"
        errors=$((errors + 1))
    fi
    
    # Test banned_ips.conf directory
    local banned_ips_dir=$(dirname "$BANNED_IPS_FILE")
    if docker exec api-gateway test -d "$banned_ips_dir"; then
        print_success "Banned IPs directory exists"
        if docker exec api-gateway test -w "$banned_ips_dir"; then
            print_success "Banned IPs directory is writable"
        else
            print_error "Banned IPs directory is not writable"
            errors=$((errors + 1))
        fi
    else
        print_error "Banned IPs directory does not exist"
        errors=$((errors + 1))
    fi
    
    return $errors
}

# Test Lua module loading
test_lua_modules() {
    print_header "Testing Lua Module Loading"
    local errors=0
    
    # First, check if modules directory is mounted correctly
    if ! docker exec api-gateway test -d /usr/local/openresty/nginx/modules; then
        print_error "Modules directory not found in container"
        return 1
    fi
    
    # List of modules that can be tested without OpenResty context
    local standalone_modules=(
        "utils"
        "config"
        "config.admin"
        "config.ip_ban"
        "config.rate_limit"
        "config.logging"
        "config.utils"
    )
    
    # List of modules that require OpenResty context
    local openresty_modules=(
        "admin"
        "ip_ban"
        "rate_limit"
        "rate_limiter"
    )
    
    print_test_description "Testing standalone modules"
    
    # Create a temporary test file using the same package path as nginx.conf
    docker exec api-gateway sh -c 'cat > /tmp/test_module.lua << "EOF"
package.path = "/usr/local/openresty/lualib/?.lua;/usr/local/openresty/nginx/modules/?.lua;/usr/local/openresty/nginx/modules/config/?.lua;;"
local name = arg[1]
local status, err = pcall(require, name)
if status then
    print("success")
else
    print("error: " .. tostring(err))
end
EOF'
    
    for module in "${standalone_modules[@]}"; do
        # Try to load each module using luajit
        local result=$(docker exec api-gateway sh -c "cd /usr/local/openresty/nginx && luajit /tmp/test_module.lua \"$module\"")
        if echo "$result" | grep -q "^success"; then
            print_success "Module '$module' loaded successfully"
        else
            print_error "Failed to load module '$module'"
            print_error "Error: $result"
            errors=$((errors + 1))
        fi
    done
    
    print_test_description "Verifying OpenResty-dependent modules exist"
    
    # For OpenResty modules, just verify they exist and are readable
    for module in "${openresty_modules[@]}"; do
        local module_path="/usr/local/openresty/nginx/modules/${module}.lua"
        if docker exec api-gateway test -f "$module_path"; then
            if docker exec api-gateway test -r "$module_path"; then
                print_success "Module '$module' exists and is readable"
            else
                print_error "Module '$module' exists but is not readable"
                errors=$((errors + 1))
            fi
        else
            print_error "Module '$module' does not exist"
            errors=$((errors + 1))
        fi
    done
    
    # Clean up
    docker exec api-gateway rm /tmp/test_module.lua
    
    return $errors
}

# Test log file creation and writing
test_logging() {
    print_header "Testing Logging System"
    local errors=0
    
    # List of required log files
    local log_files=(
        "/var/log/nginx/access.log"
        "/var/log/nginx/error.log"
        "/var/log/nginx/security.log"
    )
    
    # Check each log file
    for log_file in "${log_files[@]}"; do
        if docker exec api-gateway test -f "$log_file"; then
            print_success "Log file exists: $log_file"
            if docker exec api-gateway test -w "$log_file"; then
                print_success "Log file is writable: $log_file"
                
                # Get initial file size
                local size_before=$(docker exec api-gateway sh -c "wc -c < $log_file")
                
                # Make a request that should trigger logging
                if [[ "$log_file" == *"security.log" ]]; then
                    # For security log, make an invalid request
                    curl -s "http://localhost:${API_GATEWAY_PORT}/invalid_path_to_trigger_security_log" > /dev/null
                else
                    # For other logs, make a normal request
                    make_request "http://localhost:${API_GATEWAY_PORT}/health"
                fi
                
                sleep 2  # Give more time for logs to be written
                
                # Get new file size
                local size_after=$(docker exec api-gateway sh -c "wc -c < $log_file")
                
                if [ "$size_after" -gt "$size_before" ]; then
                    print_success "Log file is being written to: $log_file"
                    # Show the last few lines of the log
                    echo "Recent log entries:"
                    docker exec api-gateway sh -c "tail -n 3 $log_file"
                else
                    print_error "Log file is not being written to: $log_file"
                    print_error "Size before: $size_before, Size after: $size_after"
                    errors=$((errors + 1))
                fi
            else
                print_error "Log file is not writable: $log_file"
                errors=$((errors + 1))
            fi
        else
            print_error "Log file does not exist: $log_file"
            errors=$((errors + 1))
        fi
    done
    
    return $errors
}

# Test backend connectivity
test_backend_connectivity() {
    print_header "Testing Backend Connectivity"
    local errors=0
    
    # Test admin service connection
    local response=$(curl -s -w "\n%{http_code}" "http://localhost:${API_GATEWAY_PORT}/admin/health")
    local status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$status_code" -eq 200 ]; then
        print_success "Admin service is reachable"
        # Parse JSON response
        if echo "$body" | grep -q '"status":"ok"'; then
            print_success "Admin service is healthy"
        else
            print_error "Admin service is not healthy"
            print_error "Response: $body"
            errors=$((errors + 1))
        fi
    else
        print_error "Admin service is not reachable (status: $status_code)"
        print_error "Response: $body"
        errors=$((errors + 1))
    fi
    
    return $errors
}

# Run all health checks
run_health_checks() {
    local total_errors=0
    local checks_failed=0
    
    # Run each test and accumulate errors
    test_environment_variables
    total_errors=$((total_errors + $?))
    [ $? -ne 0 ] && checks_failed=$((checks_failed + 1))
    
    test_file_permissions
    total_errors=$((total_errors + $?))
    [ $? -ne 0 ] && checks_failed=$((checks_failed + 1))
    
    test_lua_modules
    total_errors=$((total_errors + $?))
    [ $? -ne 0 ] && checks_failed=$((checks_failed + 1))
    
    test_logging
    total_errors=$((total_errors + $?))
    [ $? -ne 0 ] && checks_failed=$((checks_failed + 1))
    
    test_backend_connectivity
    total_errors=$((total_errors + $?))
    [ $? -ne 0 ] && checks_failed=$((checks_failed + 1))
    
    # Print summary
    print_header "Health Check Summary"
    if [ $total_errors -eq 0 ]; then
        print_success "All health checks passed successfully!"
    else
        print_error "Health checks completed with $total_errors errors in $checks_failed check(s)"
    fi
    
    return $total_errors
}

# Run tests
setup
run_health_checks 
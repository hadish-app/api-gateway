# NGINX Configuration

The API Gateway uses NGINX as its core server, with configurations optimized for API traffic handling and enhanced with Lua capabilities through OpenResty.

## Configuration Structure

### 1. Main Configuration File

```nginx
# nginx.conf
worker_processes ${{WORKER_PROCESSES}};
error_log logs/error.log ${{LOG_LEVEL}};

events {
    worker_connections ${{WORKER_CONNECTIONS}};
}

http {
    include mime.types;
    default_type application/json;

    # Lua settings
    lua_package_path '${{LUA_PACKAGE_PATH}}';
    lua_code_cache ${{LUA_CODE_CACHE}};

    # Shared dictionaries
    lua_shared_dict stats 10m;
    lua_shared_dict config_cache 10m;
    lua_shared_dict rate_limit 10m;
    lua_shared_dict ip_blacklist 1m;

    # Server block
    server {
        listen ${{SERVER_PORT}};
        server_name ${{SERVER_NAME}};

        # Location blocks
        include locations/*.conf;
    }
}
```

### 2. Location Configuration

```nginx
# locations/default.conf
location / {
    # Access phase
    access_by_lua_block {
        require("modules.core.phase_handlers").access()
    }

    # Content phase
    content_by_lua_block {
        require("modules.core.phase_handlers").content()
    }

    # Response phases
    header_filter_by_lua_block {
        require("modules.core.phase_handlers").header_filter()
    }

    body_filter_by_lua_block {
        require("modules.core.phase_handlers").body_filter()
    }

    log_by_lua_block {
        require("modules.core.phase_handlers").log()
    }
}
```

## Core Settings

### 1. Worker Configuration

```nginx
# Worker settings
worker_processes auto;                # Auto-detect CPU cores
worker_cpu_affinity auto;            # Auto CPU affinity
worker_rlimit_nofile 65535;         # Maximum open files
worker_shutdown_timeout 30s;         # Graceful shutdown timeout

# Event settings
events {
    worker_connections 1024;         # Connections per worker
    multi_accept on;                 # Accept multiple connections
    use epoll;                      # Use epoll event model
}
```

### 2. HTTP Settings

```nginx
# HTTP core settings
http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 100;
    types_hash_max_size 2048;
    server_tokens off;

    # Buffer settings
    client_body_buffer_size 128k;
    client_max_body_size 10m;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 8k;

    # Timeouts
    client_body_timeout 12;
    client_header_timeout 12;
    send_timeout 10;
}
```

## Lua Integration

### 1. Package Path

```nginx
# Lua package path
lua_package_path '${prefix}?.lua;${prefix}?/init.lua;;';
lua_package_cpath '${prefix}?.so;;';

# Code cache settings
lua_code_cache on;  # Disable in development
```

### 2. Shared Dictionaries

```nginx
# Statistics and metrics
lua_shared_dict stats 10m;
lua_shared_dict metrics 10m;

# Configuration and caching
lua_shared_dict config_cache 10m;
lua_shared_dict route_cache 10m;

# Security
lua_shared_dict rate_limit 10m;
lua_shared_dict ip_blacklist 1m;
```

## SSL/TLS Configuration

```nginx
# SSL settings
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
ssl_session_tickets off;

# SSL certificates
ssl_certificate /path/to/cert.pem;
ssl_certificate_key /path/to/key.pem;
ssl_trusted_certificate /path/to/chain.pem;
```

## Logging Configuration

```nginx
# Error log
error_log logs/error.log ${{LOG_LEVEL}};

# Access log
log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                '$status $body_bytes_sent "$http_referer" '
                '"$http_user_agent" "$http_x_forwarded_for"';

access_log logs/access.log main buffer=32k flush=5s;
```

## Security Settings

```nginx
# Security headers
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
add_header Content-Security-Policy "default-src 'self'";

# Rate limiting
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req zone=api_limit burst=20 nodelay;

# IP blocking
deny 192.168.1.1;
allow 192.168.1.0/24;
deny all;
```

## Performance Tuning

```nginx
# File handling
sendfile on;
tcp_nopush on;
tcp_nodelay on;

# Buffers
client_body_buffer_size 128k;
client_max_body_size 10m;
client_header_buffer_size 1k;
large_client_header_buffers 4 8k;

# Timeouts
client_body_timeout 12;
client_header_timeout 12;
send_timeout 10;
keepalive_timeout 65;
keepalive_requests 100;
```

## Best Practices

### 1. Security

- Keep SSL/TLS configuration up to date
- Use secure headers
- Implement rate limiting
- Configure proper access controls

### 2. Performance

- Optimize worker settings
- Configure proper buffers
- Set appropriate timeouts
- Enable caching where appropriate

### 3. Maintenance

- Use include files for organization
- Comment configurations
- Regular security audits
- Monitor error logs

### 4. Development

- Disable code cache in development
- Use detailed logging
- Test configuration changes
- Version control configs

## Next Steps

- Learn about [Service Configuration](services.md)
- Explore [Environment Variables](environment.md)
- Read about [Configuration Overview](overview.md)

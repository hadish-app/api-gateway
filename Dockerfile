FROM openresty/openresty:1.21.4.1-6-alpine-fat

# Install dependencies
RUN opm get thibaultcha/lua-resty-jit-uuid

# Use daemon off in the main process
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"] 
FROM openresty/openresty:1.21.4.1-6-alpine-fat

# Install dependencies
RUN apk add --no-cache gcc musl-dev \
    && opm get thibaultcha/lua-resty-jit-uuid \
    && opm get spacewander/luafilesystem \
    && luarocks install luafilesystem \
    && apk del gcc musl-dev

# Use daemon off in the main process
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"] 
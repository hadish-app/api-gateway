FROM openresty/openresty:1.21.4.1-6-alpine-fat as builder

# Install build dependencies
RUN apk add --no-cache luarocks git

# Install test dependencies
RUN luarocks install busted && \
    luarocks install luassert && \
    luarocks install lua-cjson && \
    luarocks install luacov && \
    luarocks install luacov-console && \
    luarocks install --server=https://luarocks.org/dev busted-htest

# Create a smaller final image
FROM openresty/openresty:1.21.4.1-6-alpine-fat

# Copy Lua packages from builder
COPY --from=builder /usr/local/openresty/luajit /usr/local/openresty/luajit
COPY --from=builder /usr/local/openresty/lualib /usr/local/openresty/lualib

# Set working directory
WORKDIR /usr/local/openresty/nginx

# Add consolidated luarocks paths to LUA_PATH
ENV LUA_PATH="./?.lua;./modules/?.lua;./tests/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?/init.lua;/usr/local/openresty/lualib/?.lua;;"
ENV LUA_CPATH="/usr/local/openresty/luajit/lib/lua/5.1/?.so;/usr/local/openresty/lualib/?.so;;"

# Add busted to PATH
ENV PATH="/usr/local/openresty/luajit/bin:${PATH}"

# Default command to run tests
CMD ["./tests/scripts/run_tests.sh"] 
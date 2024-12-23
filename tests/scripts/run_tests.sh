#!/bin/bash

# Set LUA_PATH to include our project modules and tests
export LUA_PATH="./?.lua;./modules/?.lua;./tests/?.lua;/usr/local/openresty/lualib/?.lua;;"

# Run all tests
busted --pattern=".lua" tests/unit/

# Run specific test file (uncomment and modify as needed)
# busted tests/unit/sample_test.lua 
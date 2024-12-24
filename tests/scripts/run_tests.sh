#!/bin/bash

# Run all tests with detailed output
busted --verbose \
       --output=gtest \
       --coverage \
       --pattern=".lua" \
       tests/unit/

# Run specific test file (uncomment and modify as needed)
# busted --verbose --output=gtest tests/unit/example_module_test.lua 
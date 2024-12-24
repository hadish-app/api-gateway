#!/bin/bash

echo "============================================="
echo "1. Hadish Test Format (htest)"
echo "============================================="
busted --verbose --output=htest --pattern=".lua" tests/unit/

echo -e "\n============================================="
echo "2. plainTerminal Format"
echo "============================================="
busted --verbose --output=plainTerminal --pattern=".lua" tests/unit/

echo -e "\n============================================="
echo "3. TAP Format"
echo "============================================="
busted --verbose --output=TAP --pattern=".lua" tests/unit/

echo -e "\n============================================="
echo "4. JSON Format"
echo "============================================="
busted --verbose --output=json --pattern=".lua" tests/unit/

echo -e "\n============================================="
echo "5. JUnit Format"
echo "============================================="
busted --verbose --output=junit --pattern=".lua" tests/unit/

echo -e "\n============================================="
echo "6. gtest Format"
echo "============================================="
busted --verbose --output=gtest --pattern=".lua" tests/unit/ 
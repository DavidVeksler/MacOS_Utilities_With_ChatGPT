#!/bin/bash

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Detailed Non-Apple Running Processes (Unique by Command):${NC}"

# Get detailed info for unique non-Apple processes
ps aux | grep -v -E "Apple|/bin|/usr|/sbin|/System|/Library|awk|grep|ps|sort|uniq|bash|sh|htop|top|sudo|login|sleep" | \
awk '!seen[$11]++ {printf "%-10s %-8s %-6s %-8s %-6s %-4s %s\n", $2, $1, $3, $4, $6, $11, $12}'

# Explanation:
# - `ps aux` lists all running processes with detailed information.
# - `grep -v -E` excludes processes with common system paths and utilities.
# - `awk '!seen[$11]++'`: This part checks if the command name ($11) has been seen before. If not, it prints the process details.
# - The `awk` command formats and prints the process details.

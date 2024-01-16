#!/bin/bash

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Detailed Non-Apple Running Processes:${NC}"

# Get detailed info for non-Apple processes, excluding common system processes
ps aux | grep -v -E "Apple|/bin|/usr|/sbin|/System|/Library|awk|grep|ps|sort|uniq|bash|sh|htop|top|sudo|login|sleep" | \
awk '{printf "%-10s %-8s %-6s %-8s %-6s %-4s %s\n", $2, $1, $3, $4, $6, $11, $12}'

# Explanation:
# - `ps aux` lists all running processes with detailed information.
# - `grep -v -E` excludes processes with common system paths and utilities.
# - `awk` is used to format and print the process details:
#   - `$2`: PID
#   - `$1`: User
#   - `$3`: CPU usage
#   - `$4`: Memory usage
#   - `$6`: TTY
#   - `$11`: Command name
#   - `$12`: Additional command details

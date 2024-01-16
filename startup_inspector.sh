#!/bin/bash

# Description: This script lists non-Apple startup items, including login items, launch agents, and daemons on a macOS system.

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check for osascript
if ! command -v osascript &> /dev/null
then
    echo -e "${RED}osascript not found. This script requires osascript to run.${NC}"
    exit 1
fi

# Function to list non-Apple Login Items with additional info
list_login_items() {
    echo -e "${GREEN}Non-Apple Login Items:${NC}"
    # Using AppleScript to fetch login item names and paths
    osascript <<EOF | grep -v "Apple" | while IFS= read -r line; do
tell application "System Events"
    set loginItemsList to every login item
    set output to ""
    repeat with theItem in loginItemsList
        set theName to name of theItem
        if theName does not contain "Apple" then
            set thePath to path of theItem
            set output to output & theName & " : " & thePath & linefeed
        end if
    end repeat
    return output
end tell
EOF
        # Process and format each line of AppleScript output
        IFS=' : ' read -r name path <<< "$line"
        # Format and print the name and path
        printf "%-30s : %s\n" "$name" "$path"
    done
}

# Function to list non-Apple Launch Agents and Daemons with additional info
list_launch_agents_daemons() {
    echo -e "${GREEN}Non-Apple Launch Agents and Daemons:${NC}"

    # System-level Agents and Daemons
    echo -e "${BLUE}System-level:${NC}"
    find /System/Library/Launch{Agents,Daemons} -type f | grep -v "com.apple." | while IFS= read -r file; do
        ls -lh "$file" | awk -v file="$file" '{print file ": " $5 ", Last Modified: " $6 " " $7 " " $8}'
    done

    # User-level Agents
    echo -e "${BLUE}User-level:${NC}"
    find ~/Library/LaunchAgents -type f | grep -v "com.apple." | while IFS= read -r file; do
        ls -lh "$file" | awk -v file="$file" '{print file ": " $5 ", Last Modified: " $6 " " $7 " " $8}'
    done
    echo ""
}

# Main execution
echo -e "${GREEN}Detailed Non-Apple Startup Items Report${NC}"
echo "Generated on $(date)"
echo ""

list_login_items
list_launch_agents_daemons

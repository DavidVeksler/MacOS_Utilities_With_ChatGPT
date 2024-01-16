#!/bin/bash

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    find /System/Library/Launch{Agents,Daemons} -type f | grep -v "com.apple." | while read -r file; do
        ls -lh "$file" | awk -v file="$file" '{print file ": " $5 ", Last Modified: " $6 " " $7 " " $8}'
    done

    # User-level Agents
    echo -e "${BLUE}User-level:${NC}"
    find ~/Library/LaunchAgents -type f | grep -v "com.apple." | while read -r file; do
        ls -lh "$file" | awk -v file="$file" '{print file ": " $5 ", Last Modified: " $6 " " $7 " " $8}'
    done
    echo ""
}


# List the items
echo -e "${GREEN}Detailed Non-Apple Startup Items Report${NC}"
echo "Generated on $(date)"
echo ""

list_login_items
list_launch_agents_daemons

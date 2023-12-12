#!/bin/bash

# Function to handle file operations
handle_files() {
    local path="$1" app_name="$2" dry_run="$3"
    while IFS= read -r -d '' file; do
        [ "$dry_run" = true ] && echo "[Dry Run] Would remove: $file" || {
            echo "Removing: $file"
            rm -rf "$file" || echo "Error removing $file. You might need higher permissions."
        }
    done < <(find "$path" -name "*$app_name*" -print0 2>/dev/null)
}

# Function to uninstall an app
uninstall_app() {
    local app_name="$1" dry_run="$2"
    local app_path="/Applications/$app_name.app"
    local system_app_path="/System/Applications/$app_name.app"

    # Check for app existence in /Applications and /System/Applications
    if [ ! -d "$app_path" ]; then
        echo "Error: $app_name not found in /Applications."
        exit 1
    elif [ -d "$system_app_path" ]; then
        echo "Error: $app_name is a system application and cannot be uninstalled."
        exit 1
    fi

    # Check for special permissions or attributes
    if [ -n "$(xattr -l "$app_path" | grep -E 'restricted|system')" ]; then
        echo "Error: $app_name has restricted system permissions and cannot be uninstalled."
        exit 1
    fi

    echo "Uninstalling $app_name..."
    [ "$dry_run" = true ] && echo "[Dry Run] Would remove application: $app_path" || {
        echo "Removing application: $app_path"
        rm -rf "$app_path" || echo "Error removing $app_path. You might need higher permissions."
    }

    for dir in ~/Library/Application\ Support ~/Library/Caches ~/Library/Preferences; do
        echo "Searching for associated files in $dir"
        handle_files "$dir" "$app_name" "$dry_run"
    done

    echo "$app_name has been processed."
}

# Check if the script is run with necessary permissions
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo for proper functionality."
    exit 1
fi

# Main execution block
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <AppName> <dry_run>"
    echo "Example: $0 'YourAppNameHere' true  # Dry run mode"
    echo "Example: $0 'YourAppNameHere' false # Actual uninstall"
    exit 1
fi

uninstall_app "$1" "$2"

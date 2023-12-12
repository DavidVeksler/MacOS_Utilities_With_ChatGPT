#!/bin/bash

# Function to handle file operations
handle_files() {
    local path="$1" app_name="$2" delete_confirmed="$3"
    while IFS= read -r -d '' file; do
        local filesize=$(du -sh "$file" 2>/dev/null | cut -f1)

        if [ "$delete_confirmed" = false ]; then
            echo "[Dry Run] Found: $file (Size: $filesize)"
        else
            echo "Removing: $file (Size: $filesize)"
            if rm -rf "$file"; then
                echo "Successfully removed: $file"
            else
                echo "Error removing $file. You might need higher permissions."
            fi
        fi
    done < <(find "$path" -iname "*$app_name*" -print0 2>/dev/null)
}



# Function to check for running processes of the app
check_running_processes() {
    local app_name="$1"
    if pgrep -f "$app_name" > /dev/null; then
        echo "Warning: There are running processes related to $app_name."
        echo "It's recommended to close these processes before proceeding."
        return 1
    else
        return 0
    fi
}

# Function to check if the app is a Homebrew cask
check_homebrew_cask() {
    local app_name="$1"
    # Run the check as a regular user
    if su "$(logname)" -c "brew list --cask | grep -q '^$app_name\$'"; then
        echo "This application is managed by Homebrew."
        echo "Please exit root mode and use 'brew uninstall $app_name' to uninstall it."
        return 0
    else
        return 1
    fi
}

# Function to uninstall an app
uninstall_app() {
    local app_name="$1"
    local app_path="/Applications/$app_name.app"

     # Check if the app is a Homebrew cask
    if check_homebrew_cask "$app_name"; then
        exit 0
    fi

    # Check for running processes
    # if ! check_running_processes "$app_name"; then
    #     echo "Abort uninstallation due to running processes."
    #     exit 1
    # fi

    echo "Performing dry run for uninstalling $app_name..."

    # Dry run for main application bundle
    if [ -d "$app_path" ]; then
        local app_size=$(du -sh "$app_path" 2>/dev/null | cut -f1)
        echo "[Dry Run] Found: $app_path (Size: $app_size)"
    fi

    # Dry run for associated files
    for dir in ~/Library/Application\ Support ~/Library/Caches ~/Library/Preferences; do
        echo "Searching for associated files in $dir"
        handle_files "$dir" "$app_name" false
    done

    # Ask for confirmation to proceed with actual deletion
    read -p "Proceed with actual uninstallation? (y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo "Proceeding with actual uninstallation..."

        # Delete main application bundle
        if [ -d "$app_path" ]; then
            echo "Removing application: $app_path"
            if rm -rf "$app_path"; then
                echo "Successfully removed: $app_path"
            else
                echo "Error removing $app_path. You might need higher permissions."
            fi
        fi

        # Delete associated files
        for dir in ~/Library/Application\ Support ~/Library/Caches ~/Library/Preferences; do
            echo "Removing associated files in $dir"
            handle_files "$dir" "$app_name" true
        done
    else
        echo "Uninstallation aborted by user."
        exit 0
    fi

    echo "$app_name has been processed."
}


# Check if the script is run with necessary permissions
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo for proper functionality."
    exit 1
fi

# Main execution block
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <AppName>"
    echo "Example: $0 'YourAppNameHere'"
    exit 1
fi

uninstall_app "$1" "$2"

#!/bin/bash

# Get a list of installed apps in /Applications
find /Applications -maxdepth 1 -iname "*.app" | while read -r app; do
  bundle_id=$(mdls -name kMDItemCFBundleIdentifier -raw "$app")
  app_name=$(basename "$app" .app)

  # Check if the app's name is available in Homebrew
  echo "Checking for $app_name - $bundle_id: "

  # Search for an exact match in Homebrew
  if brew info "$app_name" >/dev/null 2>&1; then
    cask_or_formula_name="$app_name"

    # Check if the app is managed by Homebrew (case-insensitive search)
    app_managed_by_homebrew=$(brew list --cask | grep -i -E "^$cask_or_formula_name$" || brew list | grep -i -E "^$cask_or_formula_name$")

    if [[ -z "$app_managed_by_homebrew" ]]; then
      echo "$app_name is available in Homebrew as $cask_or_formula_name but not managed by it."

      # Output the package description
      cask_info=$(brew info --cask "$app_name")
      echo "Package description:"
      echo "$cask_info"
      echo ""

      # Prompt the user to replace the app with the Homebrew version
      read -u 1 -p "Do you want to replace $app_name with the Homebrew version? (y/n) " choice

      if [[ $choice == "y" ]]; then
        # Remove the existing app
        echo "Removing the existing app: $app"
        rm -rf "$app"

        # Attempt to install the Homebrew version and capture the output and error messages
        install_output=$(brew install --cask "$cask_or_formula_name" 2>&1)

        # Check the exit status of the brew install command
        if [[ $? -eq 0 ]]; then
          echo "Success! $app_name replaced with the Homebrew cask version."
        else
          # Check if the error message contains "Permission denied"
          if echo "$install_output" | grep -q "Permission denied"; then
            echo "Insufficient permissions to install $app_name. Escalating permissions with sudo."
            # Attempt to install with sudo
            if sudo brew install --cask "$cask_or_formula_name"; then
              echo "Success! $app_name replaced with the Homebrew cask version (with escalated permissions)."
            else
              echo "Failed to replace $app_name with the Homebrew cask version, even with escalated permissions."
            fi
          else
            echo "Failed to replace $app_name with the Homebrew cask version."
            echo "Installation output: $install_output"
          fi
        fi
      else
        echo "User chose not to replace $app_name with the Homebrew version."
      fi
    else
      echo "$app_name is already managed by Homebrew as $cask_or_formula_name."
    fi
  else
    echo "$app_name is not available in Homebrew."
  fi
done

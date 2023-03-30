#!/bin/bash

# Get a list of installed apps in /Applications
installed_apps=$(find /Applications -maxdepth 1 -iname "*.app")

# Check if each app is available in Homebrew
for app in $installed_apps; do
  bundle_id=$(mdls -name kMDItemCFBundleIdentifier -raw "$app")
  app_name=$(basename "$app" .app)

  # Check if the app's name is available in Homebrew
  echo "Checking for $app_name - $bundle_id: "

  # Search for an exact match in Homebrew
  if brew info "$app_name" >/dev/null 2>&1; then
    cask_or_formula_name="$app_name"

    # Check if the app is managed by Homebrew
    app_managed_by_homebrew=$(brew list --cask | grep -E "^$cask_or_formula_name$" || brew list | grep -E "^$cask_or_formula_name$")

    if [[ -z "$app_managed_by_homebrew" ]]; then
      echo "$app_name is available in Homebrew as $cask_or_formula_name but not managed by it."

      # Prompt the user to replace the app with the Homebrew version
      read -p "Do you want to replace $app_name with the Homebrew version? (y/n) " choice

      if [[ $choice == "y" ]]; then
        # Remove the existing app
        rm -rf "$app"

        # Install the Homebrew version
        if brew install --cask "$cask_or_formula_name" >/dev/null 2>&1; then
          echo "$app_name replaced with the Homebrew cask version."
        elif brew install "$cask_or_formula_name"; then
          echo "$app_name replaced with the Homebrew formula version."
        else
          echo "Failed to replace $app_name with the Homebrew version."
        fi
      fi
    fi
  fi
done

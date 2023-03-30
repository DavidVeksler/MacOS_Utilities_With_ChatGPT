#!/bin/bash

# Get the list of installed applications in the /Applications folder
installed_apps=$(ls /Applications | sed 's/.app$//')

# Get the list of Homebrew-installed applications
homebrew_apps=$(brew list --cask)

# Loop through installed applications and check if they're in Homebrew Casks and not managed by Homebrew
for app in $installed_apps; do
  # Search for the app in Homebrew Casks
  search_result=$(brew search --casks "^$app$" 2> /dev/null)

  # Check if the app is in the search result and not managed by Homebrew
  if [[ ! -z "$search_result" ]] && ! [[ $homebrew_apps =~ (^|[[:space:]])"$app"($|[[:space:]]) ]]; then
    echo "$app is available in Homebrew but not managed by Homebrew"
  fi
done

#!/bin/bash

set -e

function print_header() {
  echo "----------------------------------------"
  echo "$1"
  echo "----------------------------------------"
}

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
  echo "Homebrew is not installed. Install it from https://brew.sh and try again."
  exit 1
fi

# Check if mas is installed
if ! command -v mas &> /dev/null; then
  echo "mas is not installed. Install it using 'brew install mas' and try again."
  exit 1
fi

# Update macOS and software
print_header "Updating macOS and installed software"
softwareupdate -ia --verbose
brew update && brew upgrade && brew cleanup
mas upgrade

# Clear system caches
print_header "Clearing system caches"
sudo rm -rf /Library/Caches/*
sudo rm -rf ~/Library/Caches/*

# Clear logs
print_header "Clearing system logs"
sudo rm -rf /private/var/log/*
sudo rm -rf ~/Library/Logs/*

# Clear temporary files
print_header "Clearing temporary files"
sudo rm -rf /private/var/tmp/*
sudo rm -rf /private/var/folders/*
sudo rm -rf /tmp/*

# Clear browser caches (Safari, Chrome, and Firefox)
print_header "Clearing browser caches"
rm -rf ~/Library/Safari/LocalStorage
rm -rf ~/Library/Caches/com.apple.Safari
rm -rf ~/Library/Caches/com.apple.WebKit.PluginProcess
rm -rf ~/Library/Caches/Google/Chrome
rm -rf ~/Library/Caches/Mozilla/Firefox

# Optimize system performance
print_header "Optimizing system performance"
sudo periodic daily weekly monthly

# Verify and repair disk permissions
print_header "Verifying and repairing disk permissions"
sudo diskutil verifyVolume /
sudo diskutil repairVolume /

# Run maintenance scripts
print_header "Running maintenance scripts"
sudo /usr/libexec/locate.updatedb

# Check for potential issues
print_header "Checking for potential issues"
brew doctor
brew missing
mas outdated

echo "System maintenance complete."

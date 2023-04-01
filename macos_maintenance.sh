#!/bin/bash

# Log function
log() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Prompt for sudo password
echo "Please enter your sudo password:"
read -s PASSWORD

# Update macOS and installed software
log "Updating macOS and installed software"
echo $PASSWORD | sudo -S softwareupdate -ia & sleep 2

# Update Homebrew and installed packages
log "Updating Homebrew and installed packages"
brew update & sleep 2
brew upgrade & sleep 2

# Update Mac App Store applications
log "Updating Mac App Store applications"
mas upgrade & sleep 2

# Clearing system caches
log "Clearing system caches"
echo $PASSWORD | sudo -S rm -rf /Library/Caches/* & sleep 2
echo $PASSWORD | sudo -S rm -rf /System/Library/Caches/* & sleep 2

# Clearing system logs
log "Clearing system logs"
echo $PASSWORD | sudo -S rm -rf /private/var/log/* & sleep 2

# Clearing temporary files
log "Clearing temporary files"
echo $PASSWORD | sudo -S rm -rf /private/var/tmp/* & sleep 2
echo $PASSWORD | sudo -S rm -rf /private/var/folders/*/*/*/C/* & sleep 2
echo $PASSWORD | sudo -S rm -rf /private/var/folders/*/*/*/T/* & sleep 2
echo $PASSWORD | sudo -S rm -rf /private/var/folders/*/*/*/X/* & sleep 2

# Clearing browser caches
log "Clearing browser caches"
rm -rf ~/Library/Caches/com.apple.WebKit.PluginProcess & sleep 2
rm -rf ~/Library/Caches/com.apple.WebKit.WebContent & sleep 2
rm -rf ~/Library/Caches/com.google.Chrome & sleep 2
rm -rf ~/Library/Caches/Google/Chrome & sleep 2
rm -rf ~/Library/Caches/Mozilla/Firefox & sleep 2
rm -rf ~/Library/Caches/com.microsoft.edgemac & sleep 2
rm -rf ~/Library/Caches/com.brave.Browser & sleep 2

# Optimize system performance
log "Optimizing system performance"
echo $PASSWORD | sudo -S periodic daily weekly monthly & sleep 2

# Verify and repair disk permissions
log "Verifying and repairing disk permissions"
echo $PASSWORD | sudo -S diskutil verifyVolume / & sleep 2
echo $PASSWORD | sudo -S diskutil repairVolume / & sleep 2

# System maintenance complete
log "System maintenance complete."

#!/bin/bash

LOG_FILE="maintenance_$(date '+%Y%m%d_%H%M%S').log"

# Function to log messages and errors
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# Progress indicator with timestamp
spinner() {
  local pid=$!
  local delay=0.1
  local spinstr='\|/-'
  local start_time=$(date +%s)
  while [ "$(ps a | awk '{print $1}' | grep ${pid})" ]; do
    local temp=${spinstr#?}
    local elapsed_time=$(( $(date +%s) - start_time ))
    printf " [%c] Time: %ds " "${spinstr}" "${elapsed_time}"
    local spinstr=${temp}${spinstr%"${temp}"}
    sleep ${delay}
    printf "\b\b\b\b\b\b\b\b\b\b\b"
  done
  printf "          \b\b\b\b\b\b\b\b\b\b"
}

# Prompt for sudo password
echo "Please enter your sudo password:"
read -s SUDO_PASSWORD
echo

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
  log "Homebrew is not installed. Install it from https://brew.sh and try again."
  exit 1
fi

# Check if mas is installed
if ! command -v mas &> /dev/null; then
  log "mas is not installed. Install it using 'brew install mas' and try again."
  exit 1
fi

# Update macOS and software
log "Updating macOS and installed software"
softwareupdate -ia --verbose & spinner

log "Updating Homebrew and installed packages"
brew update && brew upgrade && brew cleanup & spinner

log "Updating Mac App Store applications"
mas upgrade & spinner

# Clear system caches
log "Clearing system caches"
echo "${SUDO_PASSWORD}" | sudo -S rm -rf /Library/Caches/* & spinner
echo "${SUDO_PASSWORD}" | sudo -S rm -rf ~/Library/Caches/* & spinner

# Clear logs
log "Clearing system logs"
echo "${SUDO_PASSWORD}" | sudo -S rm -rf /private/var/log/* & spinner
echo "${SUDO_PASSWORD}" | sudo -S rm -rf ~/Library/Logs/* & spinner

# Clear temporary files
log "Clearing temporary files"
echo "${SUDO_PASSWORD}" | sudo -S rm -rf /private/var/tmp/* & spinner
echo "${SUDO_PASSWORD}" | sudo -S rm -rf /private/var/folders/* & spinner
echo "${SUDO_PASSWORD}" | sudo -S rm -rf /tmp/* & spinner

# Clear browser caches (Safari, Chrome, Firefox, Edge, and Brave)
log "Clearing browser caches"
rm -rf ~/Library/Safari/LocalStorage & spinner
rm -rf ~/Library/Caches/com.apple.Safari & spinner
rm -rf ~/Library/Caches/com.apple.WebKit.PluginProcess & spinner
rm -rf ~/Library/Caches/Google/Chrome & spinner
rm -rf ~/Library/Caches/Mozilla/Firefox & spinner
rm -rf ~/Library/Caches/MicrosoftEdge & spinner
rm -rf ~/Library/Caches/BraveSoftware/Brave-Browser & spinner

# Optimize system performance
log "Optimizing system performance"
echo "${SUDO_PASSWORD}" | sudo periodic daily weekly monthly & spinner

# Verify and repair disk permissions
log "Verifying and repairing disk permissions"
echo "${SUDO_PASSWORD}" | sudo diskutil verifyVolume / & spinner
echo "${SUDO_PASSWORD}" | sudo diskutil repairVolume / & spinner

echo "System maintenance complete."

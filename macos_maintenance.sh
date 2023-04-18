#!/bin/bash

echo "Please enter your sudo password:"
read -s PASSWORD

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
  local prev_spin_length=0
  while [ "$(ps a | awk '{print $1}' | grep ${pid})" ]; do
    local temp=${spinstr#?}
    local elapsed_time=$(( $(date +%s) - start_time ))
    printf " [%c] Time: %ds " "${spinstr}" "${elapsed_time}"
    local spinstr=${temp}${spinstr%"${temp}"}
    local spin_length=${#spinstr}+${#elapsed_time}+11
    prev_spin_length=$spin_length
    sleep ${delay}
    printf "\b%.0s" {1..${prev_spin_length}}
  done
  printf " %.0s" {1..${prev_spin_length}}
  printf "\r\033[K"
}

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
echo $PASSWORD | sudo -S softwareupdate -ia --verbose & spinner

log "Updating Homebrew and installed packages"
brew update && brew upgrade && brew cleanup & spinner

log "Updating Mac App Store applications"
mas upgrade & spinner

# Clear system caches
log "Clearing system caches"
echo $PASSWORD | sudo -S rm -rf /Library/Caches/* 2>/dev/null & spinner
rm -rf ~/Library/Caches/* 2>/dev/null & spinner

# Clear logs
log "Clearing system logs"
echo $PASSWORD | sudo -S rm -rf /private/var/log/* 2>/dev/null & spinner
rm -rf ~/Library/Logs/* 2>/dev/null & spinner

# Clear temporary files
log "Clearing temporary files"
echo $PASSWORD | sudo -S rm -rf /private/var/tmp/* 2>/dev/null & spinner
echo $PASSWORD | sudo -S rm -rf /private/var/folders/* 2>/dev/null & spinner
rm -rf /tmp/* 2>/dev/null & spinner

# Clear browser caches (Safari, Chrome, Firefox, Edge, and Brave)
log "Clearing browser caches"
rm -rf ~/Library/Safari/LocalStorage 2>/dev/null & spinner
rm -rf ~/Library/Caches/com.apple.Safari 2>/dev/null & spinner
rm -rf ~/Library/Caches/com.apple.WebKit.PluginProcess 2>/dev/null & spinner
rm -rf ~/Library/Caches/com.apple.WebKit.WebContent 2>/dev/null & spinner
rm -rf ~/Library/Caches/com.apple.WebKit.WebContent 2>/dev/null & spinner
rm -rf ~/Library/Caches/com.google.Chrome 2>/dev/null & spinner
rm -rf ~/Library/Caches/Google/Chrome 2>/dev/null & spinner
rm -rf ~/Library/Caches/Mozilla/Firefox 2>/dev/null & spinner
rm -rf ~/Library/Caches/com.microsoft.edgemac 2>/dev/null & spinner
rm -rf ~/Library/Caches/com.brave.Browser 2>/dev/null & spinner

# Optimize system performance
log "Optimizing system performance"
echo $PASSWORD | sudo -S periodic daily weekly monthly & spinner

# Verify and repair disk permissions
log "Verifying and repairing disk permissions"
echo $PASSWORD | sudo -S diskutil verifyVolume / & spinner
echo $PASSWORD | sudo -S diskutil repairVolume / & spinner

# Rebuild Launch Services Database
# print_info "Rebuilding Launch Services Database"
# /usr/bin/sudo /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user > /dev/null 2>&1 && print_success "Launch Services Database rebuilt" || print_error "Rebuilding Launch Services Database failed"

# Reset Spotlight Index
# log "Resetting Spotlight Index"
# mdutil -i off / > /dev/null 2>&1
# mdutil -E / > /dev/null 2>&1
# mdutil -i on / > /dev/null 2>&1 && print_success "Spotlight index reset" || print_error "Resetting Spotlight index failed"

# Empty the trash
echo "Emptying the trash"
rm -rf ~/.Trash/* > /dev/null 2>&1 && echo "Trash emptied" || echo "Trash emptying failed"


# System maintenance complete
log "System maintenance complete."

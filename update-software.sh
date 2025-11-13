#!/bin/sh

echo "==> Starting update process at $(date)"
echo ""

# Update Homebrew
echo "==> Updating Homebrew..."
brew update

# Upgrade formulae
echo ""
echo "==> Upgrading formulae..."
brew upgrade

# Upgrade casks (including --greedy for auto_updates and version:latest casks)
echo ""
echo "==> Upgrading casks (including greedy mode)..."
if ! brew upgrade --cask --greedy; then
    echo ""
    echo "⚠️  Some cask upgrades failed, attempting force reinstall..."
    brew upgrade --cask --greedy --force 2>&1 | grep -E "Error:|Warning:|successfully" || true
fi

# Cleanup - consolidated into one call
echo ""
echo "==> Cleaning up old versions and cache..."
brew cleanup --prune=0

# Auto-cleanup deprecated taps
echo ""
echo "==> Removing deprecated taps..."
brew untap homebrew/services 2>/dev/null || echo "No deprecated taps to remove"

# List deprecated software for user awareness
echo ""
echo "==> Checking for deprecated software..."
DEPRECATED_CASKS=$(brew list --cask 2>/dev/null | while read cask; do
    if brew info --cask "$cask" 2>&1 | grep -qi "deprecated\|disabled"; then
        echo "$cask"
    fi
done)

if [ -n "$DEPRECATED_CASKS" ]; then
    echo "⚠️  Consider finding replacements for these deprecated casks:"
    echo "$DEPRECATED_CASKS" | sed 's/^/  - /'
fi

DEPRECATED_FORMULAE=$(brew list --formula 2>/dev/null | while read formula; do
    if brew info --formula "$formula" 2>&1 | grep -qi "deprecated\|disabled"; then
        echo "$formula"
    fi
done)

if [ -n "$DEPRECATED_FORMULAE" ]; then
    echo "⚠️  Consider finding replacements for these deprecated formulae:"
    echo "$DEPRECATED_FORMULAE" | sed 's/^/  - /'
fi

# Run brew doctor
echo ""
echo "==> Diagnosing Homebrew..."
brew doctor

# macOS software updates
echo ""
echo "==> Checking for macOS updates..."
softwareupdate -ia --verbose

# Mac App Store updates (if mas is installed)
echo ""
if command -v mas >/dev/null 2>&1; then
    echo "==> Upgrading Mac App Store apps..."
    mas upgrade
else
    echo "⚠️  'mas' not installed, skipping App Store updates"
    echo "    Install with: brew install mas"
fi

# Open Latest.app if it exists
if [ -d "/Applications/Latest.app" ]; then
    echo ""
    echo "==> Opening Latest.app..."
    open /Applications/Latest.app
else
    echo ""
    echo "⚠️  Latest.app not found, skipping"
fi

echo ""
echo "==> Update process completed at $(date)"

# Schedule this:
# ~/Library/LaunchAgents/com.veksler.update-software.plist
# <?xml version="1.0" encoding="UTF-8"?>
# <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs$
# <plist version="1.0">
# <dict>
#   <key>Label</key>
#   <string>com.veksler.update-software</string>
#   <key>ProgramArguments</key>
#   <array>
#     <string>~/Projects/Personal/update-software.sh</string>
#   </array>
#   <key>StartInterval</key>
#   <integer>86400</integer>
#   <key>RunAtLoad</key>
#   <true/>
# </dict>
# </plist>
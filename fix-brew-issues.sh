#!/bin/sh

# Script to fix common Homebrew cask issues
echo "==> Fixing Homebrew cask issues..."
echo ""

# Fix OnyX issue
echo "==> Fixing OnyX installation..."
if [ -d "/opt/homebrew/Caskroom/onyx/4.7.0" ]; then
    echo "  Removing leftover OnyX directory..."
    rm -rf /opt/homebrew/Caskroom/onyx/4.7.0
    echo "  Reinstalling OnyX..."
    brew uninstall --cask --force onyx 2>/dev/null || true
    brew install --cask onyx
else
    echo "  No OnyX issue found"
fi
echo ""

# Fix wireshark-app issue
echo "==> Fixing wireshark-app installation..."
if brew list --cask 2>/dev/null | grep -q wireshark-app; then
    echo "  Removing wireshark-app completely..."
    brew uninstall --cask --zap --force wireshark-app 2>/dev/null || true
    echo "  Reinstalling wireshark-app..."
    brew install --cask wireshark-app
else
    echo "  No wireshark-app issue found"
fi
echo ""

# Clean up orphaned caskroom directories
echo "==> Cleaning up orphaned caskroom directories..."
for cask_dir in /opt/homebrew/Caskroom/*; do
    if [ -d "$cask_dir" ]; then
        cask_name=$(basename "$cask_dir")
        if ! brew list --cask 2>/dev/null | grep -q "^${cask_name}$"; then
            echo "  Removing orphaned directory: $cask_dir"
            rm -rf "$cask_dir"
        fi
    fi
done
echo ""

# Fix coconutBattery if needed
echo "==> Checking coconutBattery..."
if brew list --cask 2>/dev/null | grep -q coconutbattery; then
    if ! brew info --cask coconutbattery >/dev/null 2>&1; then
        echo "  coconutBattery installation appears broken, fixing..."
        brew uninstall --cask --force coconutbattery 2>/dev/null || true
        brew install --cask coconutbattery
    else
        echo "  coconutBattery is OK"
    fi
else
    echo "  coconutBattery not installed"
fi
echo ""

# Run brew cleanup
echo "==> Running brew cleanup..."
brew cleanup --prune=0
echo ""

# Run brew doctor
echo "==> Running brew doctor..."
brew doctor
echo ""

echo "==> Fix process completed!"
echo "You can now run update-software.sh again"

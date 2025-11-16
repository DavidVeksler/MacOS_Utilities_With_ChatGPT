#!/bin/sh

# Color output (optional, works in most terminals)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Log file for errors
LOG_FILE="${HOME}/update-software.log"
echo "==> Starting update process at $(date)" | tee "$LOG_FILE"
echo ""

# Casks to skip (add problematic casks here)
SKIP_CASKS="logitune"

# Update Homebrew
echo "==> Updating Homebrew..."
if ! brew update 2>&1 | tee -a "$LOG_FILE"; then
    echo "${YELLOW}⚠️  Homebrew update had warnings, continuing...${NC}"
fi

# Upgrade formulae
echo ""
echo "==> Upgrading formulae..."
brew upgrade 2>&1 | tee -a "$LOG_FILE"

# Clean up broken cask installations before upgrading
echo ""
echo "==> Checking for broken cask installations..."
BROKEN_CASKS=$(brew list --cask 2>/dev/null | while read cask; do
    if ! brew info --cask "$cask" >/dev/null 2>&1; then
        echo "$cask"
    fi
done)

if [ -n "$BROKEN_CASKS" ]; then
    echo "${YELLOW}Found broken casks, attempting cleanup:${NC}"
    echo "$BROKEN_CASKS" | sed 's/^/  - /'
    for cask in $BROKEN_CASKS; do
        echo "  Cleaning up $cask..."
        brew uninstall --cask --force "$cask" 2>&1 | tee -a "$LOG_FILE" || true
    done
fi

# Upgrade casks (including --greedy for auto_updates and version:latest casks)
echo ""
echo "==> Upgrading casks (including greedy mode)..."

# First, get list of outdated casks
OUTDATED_CASKS=$(brew outdated --cask --greedy 2>/dev/null | awk '{print $1}')

if [ -z "$OUTDATED_CASKS" ]; then
    echo "No casks to upgrade."
else
    echo "Outdated casks:"
    echo "$OUTDATED_CASKS" | sed 's/^/  - /'
    echo ""

    # Track failed casks
    FAILED_CASKS=""

    # Upgrade each cask individually to better handle failures
    for cask in $OUTDATED_CASKS; do
        # Check if cask should be skipped
        if echo "$SKIP_CASKS" | grep -wq "$cask"; then
            echo "${YELLOW}⚠️  Skipping $cask (in skip list)${NC}"
            continue
        fi

        # Check if cask requires manual installation
        if brew info --cask "$cask" 2>&1 | grep -q "installer manual"; then
            echo "${YELLOW}⚠️  Skipping $cask (requires manual installation)${NC}"
            continue
        fi

        echo "Upgrading $cask..."
        if ! brew upgrade --cask "$cask" 2>&1 | tee -a "$LOG_FILE"; then
            echo "${RED}✗ Failed to upgrade $cask${NC}"
            FAILED_CASKS="$FAILED_CASKS $cask"
        else
            echo "${GREEN}✓ Successfully upgraded $cask${NC}"
        fi
        echo ""
    done

    # Handle failed casks
    if [ -n "$FAILED_CASKS" ]; then
        echo ""
        echo "${YELLOW}==> Attempting to fix failed casks...${NC}"
        for cask in $FAILED_CASKS; do
            echo "Trying to reinstall $cask..."

            # First try to uninstall with zap to remove all traces
            echo "  Removing $cask completely..."
            brew uninstall --cask --zap --force "$cask" 2>&1 | tee -a "$LOG_FILE" || true

            # Then reinstall
            echo "  Reinstalling $cask..."
            if brew install --cask "$cask" 2>&1 | tee -a "$LOG_FILE"; then
                echo "${GREEN}✓ Successfully reinstalled $cask${NC}"
                # Remove from failed list
                FAILED_CASKS=$(echo "$FAILED_CASKS" | sed "s/$cask//")
            else
                echo "${RED}✗ Failed to reinstall $cask${NC}"
            fi
            echo ""
        done

        # Final report
        if [ -n "$FAILED_CASKS" ]; then
            echo ""
            echo "${RED}==> The following casks could not be upgraded:${NC}"
            echo "$FAILED_CASKS" | tr ' ' '\n' | grep -v '^$' | sed 's/^/  - /'
            echo ""
            echo "Check the log file for details: $LOG_FILE"
        fi
    fi
fi

# Cleanup - consolidated into one call
echo ""
echo "==> Cleaning up old versions and cache..."
brew cleanup --prune=0 2>&1 | tee -a "$LOG_FILE"

# Auto-cleanup deprecated taps
echo ""
echo "==> Removing deprecated taps..."
brew untap homebrew/services 2>/dev/null || echo "No deprecated taps to remove"

# Clean up any leftover caskroom directories from failed installs
echo ""
echo "==> Cleaning up orphaned caskroom directories..."
for cask_dir in /opt/homebrew/Caskroom/*; do
    if [ -d "$cask_dir" ]; then
        cask_name=$(basename "$cask_dir")
        if ! brew list --cask 2>/dev/null | grep -q "^${cask_name}$"; then
            echo "${YELLOW}  Removing orphaned directory: $cask_dir${NC}"
            rm -rf "$cask_dir" 2>&1 | tee -a "$LOG_FILE" || true
        fi
    fi
done

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
brew doctor 2>&1 | tee -a "$LOG_FILE" || echo "${YELLOW}⚠️  brew doctor found some issues (see above)${NC}"

# macOS software updates
echo ""
echo "==> Checking for macOS updates..."
echo "${YELLOW}Note: This may require sudo password and system restart${NC}"
if softwareupdate -l 2>&1 | grep -q "No new software available"; then
    echo "No macOS updates available."
else
    echo "macOS updates are available. Run 'softwareupdate -ia' manually if you want to install them now."
    echo "(Skipping automatic installation to avoid unexpected restarts)"
fi

# Mac App Store updates (if mas is installed)
echo ""
if command -v mas >/dev/null 2>&1; then
    echo "==> Upgrading Mac App Store apps..."
    if mas upgrade 2>&1 | tee -a "$LOG_FILE"; then
        echo "${GREEN}✓ Mac App Store apps updated${NC}"
    else
        echo "${YELLOW}⚠️  Some App Store updates may have failed${NC}"
    fi
else
    echo "${YELLOW}⚠️  'mas' not installed, skipping App Store updates${NC}"
    echo "    Install with: brew install mas"
fi

# Open Latest.app if it exists
if [ -d "/Applications/Latest.app" ]; then
    echo ""
    echo "==> Opening Latest.app..."
    open /Applications/Latest.app
else
    echo ""
    echo "${YELLOW}⚠️  Latest.app not found, skipping${NC}"
    echo "    Install with: brew install --cask latest"
fi

# Final summary
echo ""
echo "======================================"
echo "==> Update Summary"
echo "======================================"
echo "Completed at: $(date)"
echo "Log file: $LOG_FILE"

# Check if there were any errors
if grep -qi "error\|failed" "$LOG_FILE"; then
    echo ""
    echo "${YELLOW}⚠️  Some errors occurred during the update process${NC}"
    echo "Review the log file for details: $LOG_FILE"
else
    echo ""
    echo "${GREEN}✓ All updates completed successfully!${NC}"
fi

echo ""
echo "Tips:"
echo "  - Run 'brew doctor' if you encounter issues"
echo "  - Run 'brew cleanup --prune=0' to free up disk space"
echo "  - Add problematic casks to SKIP_CASKS in the script"
echo ""

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
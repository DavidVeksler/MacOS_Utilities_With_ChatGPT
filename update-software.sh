#!/bin/sh
brew update
brew upgrade
brew cleanup

# Schedule THis:
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
#!/bin/bash

# Clean previous build
rm -f ./bin/MTTerminalWrapper

# Ensure output directory
mkdir -p ./bin

echo "Compiling Swift sources..."
swiftc ./src/*.swift -o ./bin/MTTerminalWrapper -target arm64-apple-macosx12.0

if [ $? -eq 0 ]; then
    echo "--------------------------------------------------------"
    echo "SUCCESS! Application built at ./bin/MTTerminalWrapper"
    echo "--------------------------------------------------------"
    echo "IMPORTANT: "
    echo "1. Run the app: ./bin/MTTerminalWrapper"
    echo "2. You MUST grant Accessibility Permissions for the mouse features to work."
    echo "   (System Settings -> Privacy & Security -> Accessibility)"
    echo "   Add the 'terminal-wrapper' executable if prompted, or add Terminal itself if running from script."
    echo "--------------------------------------------------------"
else
    echo "Build failed."
fi

#!/bin/bash

# Clean previous build
rm -f ./bin/NativeTab

# Ensure output directory
mkdir -p ./bin

echo "Compiling Swift sources..."
swiftc ./src/*.swift -o ./bin/NativeTab -target arm64-apple-macosx12.0

if [ $? -eq 0 ]; then
    echo "--------------------------------------------------------"
    echo "SUCCESS! Application built at ./bin/NativeTab"
    echo "--------------------------------------------------------"
    echo "IMPORTANT: "
    echo "1. Run the app: ./bin/NativeTab"
    echo "2. You MUST grant Accessibility Permissions for the mouse features to work."
    echo "   (System Settings -> Privacy & Security -> Accessibility)"
    echo "   Add the 'terminal-wrapper' executable if prompted, or add Terminal itself if running from script."
    echo "--------------------------------------------------------"
else
    echo "Build failed."
fi

#!/bin/bash

# This script migrates preferences from NativeTab (old) to FineTerm (new)
# Profiles (mt_connections.json) in Documents/ are safe and don't need migration.

OLD_ID="com.local.NativeTab"
NEW_ID="com.local.FineTerm"

echo "--------------------------------------------------------"
echo "▶ Checking for legacy NativeTab settings..."

# Check if old preferences exist
if ! defaults read "$OLD_ID" &>/dev/null; then
    echo "❌ No legacy settings found for '$OLD_ID'."
    echo "   Your profiles (connections) will still work automatically."
    exit 0
fi

echo "✅ Found NativeTab settings."
echo "▶ Migrating to $NEW_ID..."

# 1. Export old settings to a temporary file
defaults export "$OLD_ID" /tmp/nativetab_backup.plist

# 2. Import settings into the new app ID
defaults import "$NEW_ID" /tmp/nativetab_backup.plist

# 3. Clean up
rm /tmp/nativetab_backup.plist

echo "✅ Success! Settings transferred."
echo "   Please restart FineTerm if it is currently running."
echo "--------------------------------------------------------"

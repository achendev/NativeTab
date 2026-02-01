#!/bin/bash
set -e

APP_NAME="NativeTab"
APP_BUNDLE="$APP_NAME.app"
DMG_NAME="${APP_NAME}.dmg"
VOL_NAME="$APP_NAME"

# Check if app exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ App bundle not found. Running build script..."
    ./build.sh
fi

echo "▶ Packaging $APP_BUNDLE into $DMG_NAME..."

rm -f "$DMG_NAME"
rm -f "temp.dmg"

# Create a folder for the DMG content
mkdir -p dist
cp -R "$APP_BUNDLE" dist/
ln -s /Applications dist/Applications

# Create DMG from folder
hdiutil create -volname "$VOL_NAME" -srcfolder dist -ov -format UDZO "temp.dmg"

# Cleanup dist safely
mkdir -p /tmp/nativetab_trash
mv dist "/tmp/nativetab_trash/dist_$(date +%s)"

# Finalize name
mv "temp.dmg" "$DMG_NAME"

echo "✅  DMG Created: $DMG_NAME"

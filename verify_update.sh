#!/bin/bash
set -e

# Configuration
APP_NAME="AppleAI"
EXPECTED_VERSION="1.1.1"
INSTALLED_PATH="/Applications/$APP_NAME.app"

echo "🔍 Verifying update system..."

# Check if the app exists
if [ ! -d "$INSTALLED_PATH" ]; then
    echo "❌ Error: App not installed at $INSTALLED_PATH"
    exit 1
fi

# Check the installed version
CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INSTALLED_PATH/Contents/Info.plist")
echo "📱 Current installed version: $CURRENT_VERSION"

# Check if appcast.xml is accessible
echo "🔄 Checking GitHub release appcast..."
APPCAST_URL="https://github.com/bunnysayzz/AppleAI-update/releases/latest/download/appcast.xml"
APPCAST_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APPCAST_URL")

if [ "$APPCAST_STATUS" = "200" ]; then
    echo "✅ Appcast is accessible at $APPCAST_URL"
else
    echo "❌ Error: Appcast not accessible (HTTP status: $APPCAST_STATUS)"
    echo "   Please make sure you've uploaded appcast.xml to the GitHub release"
    exit 1
fi

# Check if the ZIP download URL works
ZIP_URL="https://github.com/bunnysayzz/AppleAI-update/releases/download/v$EXPECTED_VERSION/AppleAI-$EXPECTED_VERSION.zip"
ZIP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$ZIP_URL")

if [ "$ZIP_STATUS" = "200" ]; then
    echo "✅ Release ZIP is accessible at $ZIP_URL"
else
    echo "❌ Error: Release ZIP not accessible (HTTP status: $ZIP_STATUS)"
    echo "   Please make sure you've uploaded AppleAI-$EXPECTED_VERSION.zip to the GitHub release"
    exit 1
fi

echo ""
echo "🚀 Update system verification:"
echo "----------------------------"
if [ "$CURRENT_VERSION" = "$EXPECTED_VERSION" ]; then
    echo "✅ Update successful! App version is $CURRENT_VERSION"
else
    echo "❓ App version is $CURRENT_VERSION, expected $EXPECTED_VERSION"
    echo "   If you just installed, try running the app and checking for updates"
fi 
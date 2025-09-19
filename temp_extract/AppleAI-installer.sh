#!/bin/bash
APP_PATH="/Applications/AppleAI.app"
EXTRACT_PATH="$PWD/temp_extract/AppleAI.app"
echo "Preparing to update AppleAI..."
echo "Current app path: $APP_PATH"
echo "New version path: $EXTRACT_PATH"
echo "Closing AppleAI if running..."
pkill -x "AppleAI" || true
sleep 2
echo "Replacing application..."
sudo rm -rf "$APP_PATH"
sudo cp -R "$EXTRACT_PATH" "$APP_PATH"
sudo chmod -R 755 "$APP_PATH"
echo "Update completed successfully!"
echo "Starting new version..."
open "$APP_PATH"

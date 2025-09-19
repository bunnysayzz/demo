#!/bin/bash

# Exit on any error
set -e

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="Apple AI"
SERVER_DIR="server/updates"

echo -e "${BLUE}AppleAI - Release Builder${NC}"
echo "==========================================="

# Step 1: Extract version from appcast.xml
echo "Extracting version from appcast.xml..."
VERSION=$(grep -o 'sparkle:version="[^"]*"' appcast.xml | head -1 | cut -d'"' -f2)

if [ -z "$VERSION" ]; then
    echo -e "${YELLOW}Warning: Could not extract version from appcast.xml. Using default 1.0.0${NC}"
    VERSION="1.0.0"
fi

echo -e "${GREEN}Building version $VERSION${NC}"

# Step 2: Run the main build script
echo -e "\n${BLUE}Step 1: Running build script${NC}"
chmod +x build.sh
./build.sh

# Step 3: Create zip file for update system
echo -e "\n${BLUE}Step 2: Creating zip file for update system${NC}"
ZIP_FILE="AppleAI-${VERSION}.zip"
echo "Creating ${ZIP_FILE}..."

# Remove existing zip file if it exists
if [ -f "${ZIP_FILE}" ]; then
    echo "Removing existing zip file..."
    rm -f "${ZIP_FILE}"
fi

# Create the zip file
zip -r "${ZIP_FILE}" "AppleAI.app"

# Step 4: Set up server directory
echo -e "\n${BLUE}Step 3: Setting up server directory${NC}"
mkdir -p "${SERVER_DIR}"

# Copy appcast.xml to server directory
echo "Copying appcast.xml to server directory..."
cp appcast.xml "${SERVER_DIR}/"

# Copy zip file to server directory
echo "Copying ${ZIP_FILE} to server directory..."
if [ -f "${SERVER_DIR}/${ZIP_FILE}" ]; then
    echo "Removing existing zip file in server directory..."
    rm -f "${SERVER_DIR}/${ZIP_FILE}"
fi
cp "${ZIP_FILE}" "${SERVER_DIR}/"

# Step 5: Update appcast.xml with correct file size
ZIP_SIZE=$(stat -f%z "${ZIP_FILE}")
echo "Updating appcast.xml with correct file size: ${ZIP_SIZE} bytes"

# Update file size in appcast.xml in server directory
sed -i '' "s/length=\"[0-9]*\"/length=\"${ZIP_SIZE}\"/" "${SERVER_DIR}/appcast.xml"

echo -e "\n${GREEN}Release process completed successfully!${NC}"
echo "App Version: ${VERSION}"
echo "DMG: Apple_AI_Universal.dmg"
echo "Update Zip: ${ZIP_FILE}"
echo "Server Directory: ${SERVER_DIR}"
echo -e "To start the server, run: ./runserver.sh\n"

exit 0
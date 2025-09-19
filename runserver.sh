#!/bin/bash

# Exit on any error
set -e

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_DIR="server"
SERVER_PORT=8000

echo -e "${BLUE}AppleAI - Update Server${NC}"
echo "==========================================="

# Check if the server directory exists
if [ ! -d "$SERVER_DIR" ]; then
    echo -e "${YELLOW}Error: Server directory '$SERVER_DIR' not found.${NC}"
    echo "Please run release.sh first to create the server directory."
    exit 1
fi

# Check if there are any zip files in the updates directory
ZIP_COUNT=$(find "$SERVER_DIR/updates" -name "*.zip" | wc -l)
if [ "$ZIP_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}Warning: No zip files found in '$SERVER_DIR/updates'.${NC}"
    echo "Update functionality may not work correctly."
fi

# Check if appcast.xml exists in the updates directory
if [ ! -f "$SERVER_DIR/updates/appcast.xml" ]; then
    echo -e "${YELLOW}Error: appcast.xml not found in '$SERVER_DIR/updates'.${NC}"
    echo "Please run release.sh first to create the appcast.xml file."
    exit 1
fi

# Check if a process is already running on the specified port
if lsof -i:$SERVER_PORT > /dev/null; then
    echo -e "${YELLOW}Warning: Port $SERVER_PORT is already in use.${NC}"
    echo "Stopping the existing process..."
    lsof -ti:$SERVER_PORT | xargs kill -9 2>/dev/null || true
    echo "Waiting for port to become available..."
    sleep 2
fi

# Start the HTTP server
echo -e "\n${GREEN}Starting HTTP server on port $SERVER_PORT...${NC}"
echo -e "Server URL: http://localhost:$SERVER_PORT"
echo -e "Update Feed URL: http://localhost:$SERVER_PORT/updates/appcast.xml"
echo -e "Press Ctrl+C to stop the server.\n"

# Change to the server directory and start the Python HTTP server
cd "$SERVER_DIR" && python3 -m http.server $SERVER_PORT

exit 0 
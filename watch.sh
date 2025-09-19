#!/bin/bash

# Exit on any error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🍎 Apple AI - Auto Build Watcher${NC}"
echo "=========================================="
echo -e "${GREEN}Starting file watcher...${NC}"
echo -e "${GREEN}Press Ctrl+C to stop${NC}"
echo ""

# Install fswatch if not installed
if ! command -v fswatch &> /dev/null; then
    echo -e "${YELLOW}fswatch not found. Installing...${NC}"
    brew install fswatch
fi

# Check if build.sh exists and is executable
if [ ! -f "./build.sh" ]; then
    echo -e "${RED}Error: build.sh not found in current directory${NC}"
    exit 1
fi

# Make build.sh executable
chmod +x ./build.sh

echo -e "${BLUE}Watching for changes in AppleAI project...${NC}"
echo -e "${BLUE}Build script will run automatically on file changes${NC}"
echo ""

# Watch for changes in these directories
fswatch -o \
    -e "\.git" \
    -e "\.build" \
    -e "\.swiftpm" \
    -e "DerivedData" \
    -e "build" \
    -e "\.DS_Store" \
    -e "\.swiftpm/xcode" \
    -e "\.swiftpm/xcode/.*" \
    -e "\.swiftpm/.*" \
    -e "\.git/.*" \
    -e "temp" \
    -e "tmp" \
    -e "*.dmg" \
    -e "*.zip" \
    . | while read -r event; do
    
    echo -e "\n${GREEN}🔄 Changes detected!${NC} Running build script..."
    echo "========================================"
    
    # Run the build script
    if ! ./build.sh; then
        echo -e "\n${RED}❌ Build failed!${NC} Fix the errors and save again."
        echo -e "${YELLOW}Check the error messages above for details.${NC}"
    else
        echo -e "\n${GREEN}✅ Build completed successfully!${NC}"
        echo -e "${BLUE}📱 App is ready to test${NC}"
        echo -e "${GREEN}👀 Watching for changes...${NC}"
    fi
    
    echo "========================================"
done

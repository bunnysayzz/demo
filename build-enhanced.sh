#!/bin/bash

# Enhanced AppleAI Build Script for macOS
# This script should be run on macOS with Xcode installed

# Exit on any error
set -e

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Enhanced Apple AI - Build Script${NC}"
echo "=================================="
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script must be run on macOS with Xcode installed.${NC}"
    echo "Please transfer this project to a macOS machine and run this script there."
    exit 1
fi

# Check required tools
echo "Checking required tools..."

if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: xcodebuild is not available. Please install Xcode.${NC}"
    exit 1
fi

if ! command -v /usr/libexec/PlistBuddy &> /dev/null; then
    echo -e "${RED}Error: PlistBuddy is not available. Please ensure you're on macOS.${NC}"
    exit 1
fi

# Configuration
APP_NAME="Apple AI"
VERSION="2.2.0" # Enhanced version

echo -e "${GREEN}Building Enhanced Apple AI version $VERSION${NC}"

# Update Info.plist with the new version
echo "Updating Info.plist with version $VERSION..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "AppleAI/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "AppleAI/Info.plist"

# Update bundle name to reflect enhanced version
/usr/libexec/PlistBuddy -c "Set :CFBundleName Apple AI Pro" "AppleAI/Info.plist"

# Determine the project path and scheme
if [ -d "AppleAI.xcodeproj" ]; then
    PROJECT_PATH="AppleAI.xcodeproj"
    SCHEME="AppleAI"
    echo "Found AppleAI.xcodeproj in current directory"
else
    echo -e "${RED}Error: Could not find AppleAI.xcodeproj${NC}"
    exit 1
fi

# Clean previous builds
echo -e "\n${BLUE}Step 1: Building Enhanced Universal Binary${NC}"
echo "Cleaning previous builds..."
rm -rf build/
mkdir -p build/

# Build for Apple Silicon (arm64)
echo "Building for Apple Silicon (arm64)..."
xcodebuild -project "$PROJECT_PATH" \
           -scheme "$SCHEME" \
           -configuration Release \
           -destination 'platform=macOS,arch=arm64' \
           -derivedDataPath build/arm64 \
           clean build

# Build for Intel (x86_64)
echo "Building for Intel (x86_64)..."
xcodebuild -project "$PROJECT_PATH" \
           -scheme "$SCHEME" \
           -configuration Release \
           -destination 'platform=macOS,arch=x86_64' \
           -derivedDataPath build/x86_64 \
           clean build

# Find the built app paths
ARM64_APP_PATH=$(find build/arm64 -name "*.app" -type d | head -n 1)
X86_64_APP_PATH=$(find build/x86_64 -name "*.app" -type d | head -n 1)

if [ -z "$ARM64_APP_PATH" ] || [ -z "$X86_64_APP_PATH" ]; then
    echo -e "${RED}Error: Could not find built apps${NC}"
    exit 1
fi

# Create universal binary
echo -e "\n${BLUE}Step 2: Creating Enhanced Universal Binary${NC}"

# Create directory for universal binary
mkdir -p build/universal

# Get app name from path
APP_NAME=$(basename "$ARM64_APP_PATH")
UNIVERSAL_APP_PATH="build/universal/$APP_NAME"

# Create Universal App by copying the ARM64 version as a base
cp -R "$ARM64_APP_PATH" "$UNIVERSAL_APP_PATH"

# Get executable name from Info.plist
EXECUTABLE_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$UNIVERSAL_APP_PATH/Contents/Info.plist")

# Create universal binary executable
ARM64_BIN="$ARM64_APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
X86_64_BIN="$X86_64_APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
UNIVERSAL_BIN="$UNIVERSAL_APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"

lipo -create -output "$UNIVERSAL_BIN" "$ARM64_BIN" "$X86_64_BIN"

# Verify the universal binary
echo "Verifying universal binary:"
lipo -info "$UNIVERSAL_BIN"

# Update Info.plist with enhanced version info
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${UNIVERSAL_APP_PATH}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${UNIVERSAL_APP_PATH}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Apple AI Pro" "${UNIVERSAL_APP_PATH}/Contents/Info.plist"

# Remove quarantine attributes
echo "Removing quarantine attributes from the app..."
xattr -rc "${UNIVERSAL_APP_PATH}"

# Remove existing app in the current directory if it exists
if [ -d "./${APP_NAME}" ]; then
    echo "Removing existing app in current directory..."
    rm -rf "./${APP_NAME}"
fi

# Copy the universal app to the current directory
echo "Copying universal app to current directory..."
cp -R "$UNIVERSAL_APP_PATH" "./${APP_NAME}"

echo -e "${GREEN}Enhanced universal app built successfully at: ./${APP_NAME}${NC}"

# Enhanced signing with proper entitlements
echo -e "\n${BLUE}Step 3: Signing Enhanced App with Proper Entitlements${NC}"

# Create enhanced entitlements file
ENTITLEMENTS_TEMP="${TMPDIR}enhanced_entitlements.plist"
cat > "${ENTITLEMENTS_TEMP}" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.device.microphone</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
</dict>
</plist>
EOL

echo "Using enhanced entitlements:"
cat "${ENTITLEMENTS_TEMP}"
echo ""

# Check for signing identities
SIGNING_IDENTITIES=$(security find-identity -v -p codesigning | grep -c "valid identities")

if [ "$SIGNING_IDENTITIES" -gt 0 ]; then
    echo "Found valid code signing identities. Attempting to sign..."
    
    if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
        DEV_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F '"' '{print $2}')
        echo "Signing with Developer ID: $DEV_ID"
        codesign --force --deep --options runtime --entitlements "${ENTITLEMENTS_TEMP}" --sign "$DEV_ID" "./${APP_NAME}"
    elif security find-identity -v -p codesigning | grep -q "Mac Developer"; then
        MAC_DEV=$(security find-identity -v -p codesigning | grep "Mac Developer" | head -1 | awk -F '"' '{print $2}')
        echo "Signing with Mac Developer: $MAC_DEV"
        codesign --force --deep --options runtime --entitlements "${ENTITLEMENTS_TEMP}" --sign "$MAC_DEV" "./${APP_NAME}"
    else
        echo -e "${YELLOW}Using ad-hoc signing.${NC}"
        codesign --force --deep --options runtime --entitlements "${ENTITLEMENTS_TEMP}" --sign - "./${APP_NAME}"
    fi
else
    echo -e "${YELLOW}No valid code signing identities found. Using ad-hoc signing.${NC}"
    codesign --force --deep --options runtime --entitlements "${ENTITLEMENTS_TEMP}" --sign - "./${APP_NAME}"
fi

# Clean up entitlements file
rm -f "${ENTITLEMENTS_TEMP}"

# Verify signature
echo "Verifying code signature..."
codesign -dv --verbose=2 "./${APP_NAME}"

# Create enhanced DMG
echo -e "\n${BLUE}Step 4: Creating Enhanced DMG Installer${NC}"

DMG_NAME="Apple_AI_Pro_Enhanced"
DMG_FINAL="${DMG_NAME}_v${VERSION}.dmg"
VOLUME_NAME="Apple AI Pro ${VERSION}"

# Remove existing DMG
if [ -f "${DMG_FINAL}" ]; then
    echo "Removing existing DMG file..."
    rm -f "${DMG_FINAL}"
fi

# Create DMG staging directory
TMP_DIR="tmp_dmg_enhanced"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"

# Copy app to staging
cp -R "${APP_NAME}" "${TMP_DIR}/"

# Create a README for users
cat > "${TMP_DIR}/README.txt" <<EOL
Apple AI Pro - Enhanced Edition v${VERSION}

INSTALLATION:
1. Drag "Apple AI" to your Applications folder
2. Launch from Applications or Spotlight
3. The app will appear in your menu bar

FIRST RUN:
- If you see a "damaged app" error, go to System Settings > Privacy & Security
- Scroll down and click "Open Anyway" next to the Apple AI message
- Or run this command in Terminal: xattr -cr "/Applications/Apple AI.app"

FEATURES:
✨ Modern theme system with Light/Dark/Auto modes
🎨 12 accent color options for personalization
🤖 Multiple AI assistants in one interface
🔒 Privacy-first design with local data storage
⚡ Enhanced performance and memory management
♿ Full accessibility support

SUPPORT:
- GitHub: https://github.com/bunnysayzz/AppleAI
- Website: https://macbunny.co

Enjoy your enhanced AI assistant hub!
EOL

# Create DMG
if command -v create-dmg &> /dev/null; then
    echo "Creating enhanced DMG with create-dmg..."
    create-dmg \
        --volname "${VOLUME_NAME}" \
        --window-pos 200 120 \
        --window-size 800 600 \
        --icon-size 128 \
        --icon "${APP_NAME}" 200 320 \
        --hide-extension "${APP_NAME}" \
        --app-drop-link 600 320 \
        --no-internet-enable \
        "${DMG_FINAL}" \
        "${TMP_DIR}" || {
            echo -e "${YELLOW}create-dmg failed. Using hdiutil...${NC}"
            hdiutil create -volname "${VOLUME_NAME}" -srcfolder "${TMP_DIR}" -ov -format UDZO "${DMG_FINAL}"
        }
else
    echo "Using hdiutil to create DMG..."
    hdiutil create -volname "${VOLUME_NAME}" -srcfolder "${TMP_DIR}" -ov -format UDZO "${DMG_FINAL}"
fi

# Clean up staging directory
rm -rf "${TMP_DIR}"

# Final verification
if [ -f "${DMG_FINAL}" ]; then
    echo -e "${GREEN}Enhanced Apple AI built successfully!${NC}"
    echo ""
    echo "📱 Universal App: ./${APP_NAME}"
    echo "💿 DMG Installer: ./${DMG_FINAL}"
    echo "🔢 Version: ${VERSION}"
    echo ""
    echo -e "${BLUE}Enhancement Summary:${NC}"
    echo "✅ Comprehensive theme system implemented"
    echo "✅ Modern UI components with macOS design guidelines"
    echo "✅ Enhanced preferences with 6 organized sections"
    echo "✅ Advanced session persistence and analytics"
    echo "✅ Improved performance and memory management"
    echo "✅ Full accessibility compliance"
    echo "✅ Privacy-first design with local storage"
    echo ""
    echo -e "${GREEN}Ready for distribution! 🎉${NC}"
else
    echo -e "${RED}Build failed - DMG not created${NC}"
    exit 1
fi

exit 0
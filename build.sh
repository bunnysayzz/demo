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

# Extract version from appcast.xml
echo "Extracting version from appcast.xml..."
VERSION=$(grep -o 'sparkle:version="[^"]*"' appcast.xml | head -1 | cut -d'"' -f2)

if [ -z "$VERSION" ]; then
    echo -e "${YELLOW}Warning: Could not extract version from appcast.xml. Using default 1.0.0${NC}"
    VERSION="1.0.0"
fi

echo -e "${GREEN}Building version $VERSION${NC}"

# Update Info.plist with the version from appcast.xml
echo "Updating Info.plist with version $VERSION..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "AppleAI/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "AppleAI/Info.plist"

DMG_NAME="Apple_AI_Universal"
DMG_FINAL="${DMG_NAME}.dmg"
VOLUME_NAME="Apple AI ${VERSION}"

echo -e "${BLUE}Apple AI - Universal Build & DMG Creator${NC}"
echo "==========================================="
echo "Building universal app version ${VERSION} and creating DMG installer..."
echo ""

# Check required tools
echo "Checking required tools..."

if ! command -v xcodebuild &> /dev/null; then
    echo -e "${YELLOW}Error: xcodebuild is not available. Please make sure Xcode is installed.${NC}"
    exit 1
fi

if ! command -v create-dmg &> /dev/null; then
    echo -e "${YELLOW}Warning: create-dmg tool is not installed.${NC}"
    echo "Installing create-dmg using Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Error: Homebrew is not installed. Please install Homebrew first.${NC}"
        echo "Visit https://brew.sh for installation instructions."
        exit 1
    fi
    brew install create-dmg
fi

# Determine the project path and scheme
if [ -d "AppleAI/AppleAI.xcodeproj" ]; then
    PROJECT_PATH="AppleAI/AppleAI.xcodeproj"
    SCHEME="AppleAI"
    echo "Found AppleAI.xcodeproj in AppleAI/ directory"
elif [ -d "AppleAI.xcodeproj" ]; then
    PROJECT_PATH="AppleAI.xcodeproj"
    SCHEME="AppleAI"
    echo "Found AppleAI.xcodeproj in current directory"
else
    echo -e "${YELLOW}Error: Could not find Xcode project${NC}"
    exit 1
fi

        # Clean previous builds
        echo -e "\n${BLUE}Step 1: Building Universal Binary${NC}"
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
            echo -e "${YELLOW}Error: Could not find built apps${NC}"
            exit 1
        fi
        
        # Create universal binary
        echo -e "\n${BLUE}Step 2: Creating Universal Binary${NC}"
        
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

# Make sure the Info.plist has the correct version
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${UNIVERSAL_APP_PATH}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${UNIVERSAL_APP_PATH}/Contents/Info.plist"
        
        # Remove quarantine attributes that might be added during the build process
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
        
        echo -e "${GREEN}Universal app built successfully at: ./${APP_NAME}${NC}"

# Properly sign the app with entitlements for microphone access
echo -e "\n${BLUE}Step 3: Signing the app with proper entitlements${NC}"

# Create a temporary entitlements file with required permissions
ENTITLEMENTS_TEMP="${TMPDIR}temp_entitlements.plist"
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
</dict>
</plist>
EOL

echo "Using entitlements for microphone access:"
cat "${ENTITLEMENTS_TEMP}"
echo ""

# Check if we have any available signing identities
SIGNING_IDENTITIES=$(security find-identity -v -p codesigning | grep -c "valid identities")

if [ "$SIGNING_IDENTITIES" -gt 0 ]; then
    echo "Found valid code signing identities. Attempting to sign with developer ID..."
    
    # Try to sign with Developer ID (best option)
    if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
        DEV_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F '"' '{print $2}')
        echo "Signing with Developer ID: $DEV_ID"
        codesign --force --deep --options runtime --entitlements "${ENTITLEMENTS_TEMP}" --sign "$DEV_ID" "./${APP_NAME}"
    # Otherwise try with Mac Developer
    elif security find-identity -v -p codesigning | grep -q "Mac Developer"; then
        MAC_DEV=$(security find-identity -v -p codesigning | grep "Mac Developer" | head -1 | awk -F '"' '{print $2}')
        echo "Signing with Mac Developer: $MAC_DEV"
        codesign --force --deep --options runtime --entitlements "${ENTITLEMENTS_TEMP}" --sign "$MAC_DEV" "./${APP_NAME}"
    # As a last resort, use ad-hoc signing
    else
        echo -e "${YELLOW}No Developer ID or Mac Developer certificate found. Using ad-hoc signing.${NC}"
        codesign --force --deep --options runtime --entitlements "${ENTITLEMENTS_TEMP}" --sign - "./${APP_NAME}"
    fi
else
    echo -e "${YELLOW}No valid code signing identities found. Using ad-hoc signing.${NC}"
    echo "Note: Ad-hoc signed apps may be blocked by Gatekeeper on macOS."
    codesign --force --deep --options runtime --entitlements "${ENTITLEMENTS_TEMP}" --sign - "./${APP_NAME}"
fi

# Clean up temporary entitlements file
rm -f "${ENTITLEMENTS_TEMP}"

# Verify the signature
echo "Verifying code signature..."
codesign -dv --verbose=2 "./${APP_NAME}"

# Create DMG
echo -e "\n${BLUE}Step 3: Creating Premium DMG Installer${NC}"
    
    # Remove any existing DMG file
    if [ -f "${DMG_FINAL}" ]; then
        echo "Removing existing DMG file..."
        rm -f "${DMG_FINAL}"
    fi
    
    # Create a temporary directory for DMG contents
    echo "Setting up DMG contents..."
    TMP_DIR="tmp_dmg"
    rm -rf "${TMP_DIR}"
    mkdir -p "${TMP_DIR}"
    mkdir -p "${TMP_DIR}/.background"
    
# Prepare background image - creating a premium white dotted background
    BACKGROUND_IMG="${TMP_DIR}/.background/background.png"
    
    # Try to create a background image if ImageMagick is available
    if command -v convert &> /dev/null; then
    echo "Creating premium background image with white dotted pattern..."
    
    # Create a high-quality white dotted pattern background (800x600)
    convert -size 800x600 xc:white \
        -fill "#f7f7f7" \
        -draw "point 10,10 point 20,10 point 30,10 point 40,10 point 50,10 point 60,10 point 70,10 point 80,10" \
        -draw "point 10,20 point 20,20 point 30,20 point 40,20 point 50,20 point 60,20 point 70,20 point 80,20" \
        -draw "point 10,30 point 20,30 point 30,30 point 40,30 point 50,30 point 60,30 point 70,30 point 80,30" \
        -draw "point 10,40 point 20,40 point 30,40 point 40,40 point 50,40 point 60,40 point 70,40 point 80,40" \
        -draw "point 10,50 point 20,50 point 30,50 point 40,50 point 50,50 point 60,50 point 70,50 point 80,50" \
        -virtual-pixel tile -tile-offset 0x0 -background white \
        -splice 0x0 -gravity center -extent 800x600 \
        "${TMP_DIR}/.background/pattern.png"

    # Create a modern arrow effect
    convert -size 800x600 xc:none \
        -fill "#0080ff" -stroke "#0080ff" -strokewidth 4 \
        -draw "path 'M 330,300 L 440,300 L 440,275 L 490,320 L 440,365 L 440,340 L 330,340 Z'" \
        "${TMP_DIR}/.background/arrow.png"

    # Add a subtle shadow to the arrow
    convert "${TMP_DIR}/.background/arrow.png" \
        \( +clone -background black -shadow 80x3+2+2 \) \
        +swap -background none -layers merge +repage \
        "${TMP_DIR}/.background/arrow-shadow.png"
    
    # Combine pattern with arrow
    convert "${TMP_DIR}/.background/pattern.png" \
        "${TMP_DIR}/.background/arrow-shadow.png" \
        -gravity center -compose over -composite \
        -fill "#1d1d1f" -pointsize 16 -gravity north -annotate +0+20 "Drag to install" \
            "${BACKGROUND_IMG}"
        
    # Clean up temporary files
    rm -f "${TMP_DIR}/.background/pattern.png" "${TMP_DIR}/.background/arrow.png" "${TMP_DIR}/.background/arrow-shadow.png"
    else
        # Simple fallback for background
        echo "Warning: ImageMagick not installed. Using simple background."
    
        # Create a blank file
        touch "${BACKGROUND_IMG}"
    fi
    
    # Copy the app to the temporary directory
    echo "Copying app to DMG staging area..."
    cp -R "${APP_NAME}" "${TMP_DIR}/"
    
    # Create the DMG
    echo "Creating DMG with create-dmg..."
    if command -v create-dmg &> /dev/null; then
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
                echo -e "${YELLOW}DMG creation failed. Trying simpler method...${NC}"
                hdiutil create -volname "${VOLUME_NAME}" -srcfolder "${TMP_DIR}" -ov -format UDZO "${DMG_FINAL}"
            }
    else
        echo "create-dmg not found, using hdiutil directly..."
        hdiutil create -volname "${VOLUME_NAME}" -srcfolder "${TMP_DIR}" -ov -format UDZO "${DMG_FINAL}"
    fi
    
    # Check if DMG creation was successful
    if [ -f "${DMG_FINAL}" ]; then
        echo -e "${GREEN}DMG created successfully: ${DMG_FINAL}${NC}"
        
        # Try to sign the DMG if we have a valid identity
        if [ "$SIGNING_IDENTITIES" -gt 0 ]; then
            echo "Attempting to sign DMG..."
            if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
                DEV_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F '"' '{print $2}')
                echo "Signing DMG with Developer ID: $DEV_ID"
                codesign --force --sign "$DEV_ID" "${DMG_FINAL}"
            fi
        fi
    else
        echo -e "${YELLOW}Failed to create DMG.${NC}"
        exit 1
    fi
    
    # Clean up
    echo "Cleaning up temporary files..."
    rm -rf "${TMP_DIR}"
    find "$(dirname "$0")" -name "rw.*.dmg" -type f -delete 2>/dev/null || true

# Add user instructions for 'damaged app' errors
echo -e "${YELLOW}=== IMPORTANT NOTES FOR DISTRIBUTION ===${NC}"
echo -e "1. If users see a 'damaged app' error, they need to:"
echo -e "   - Open System Settings > Privacy & Security"
echo -e "   - Scroll down and click 'Open Anyway'"
echo -e "   - Or run in Terminal: xattr -cr '/Applications/Apple AI.app'"
echo -e "2. For proper distribution, consider obtaining an Apple Developer certificate"
echo -e "   and notarizing the app through Apple's notary service."
echo -e "3. Instructions for users are included in the INSTALL_INFO.txt file in the DMG."

echo -e "\n${GREEN}Build process completed successfully!${NC}"
echo "Universal App: ./${APP_NAME}"
echo "DMG Installer: ./${DMG_FINAL}"
echo -e "Version: ${VERSION}\n"

exit 0 
#!/bin/bash

# AI Assistant Pro - APK Build Script
# This script builds a production-ready APK for distribution

set -e

echo "🤖 AI Assistant Pro - APK Build Script"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"
    
    # Check Java
    if ! command -v java &> /dev/null; then
        echo -e "${RED}❌ Java not found. Please install JDK 11 or higher.${NC}"
        exit 1
    fi
    
    JAVA_VERSION=$(java -version 2>&1 | head -n1 | cut -d'"' -f2 | cut -d'.' -f1)
    if [ "$JAVA_VERSION" -lt 11 ]; then
        echo -e "${RED}❌ Java 11+ required. Found Java $JAVA_VERSION${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Java $JAVA_VERSION found${NC}"
    
    # Check Android SDK (optional)
    if [ -z "$ANDROID_HOME" ] && [ ! -d "$HOME/Android/Sdk" ]; then
        echo -e "${YELLOW}⚠️  Android SDK not found. This is optional for source distribution.${NC}"
        echo -e "${YELLOW}   To build APK, install Android Studio and set ANDROID_HOME${NC}"
    else
        echo -e "${GREEN}✅ Android SDK path configured${NC}"
    fi
}

# Clean previous builds
clean_build() {
    echo -e "${BLUE}🧹 Cleaning previous builds...${NC}"
    
    if [ -d "app/build" ]; then
        rm -rf app/build
        echo -e "${GREEN}✅ Cleaned app/build directory${NC}"
    fi
    
    if [ -d "build" ]; then
        rm -rf build
        echo -e "${GREEN}✅ Cleaned build directory${NC}"
    fi
}

# Build APK
build_apk() {
    echo -e "${BLUE}🔨 Building APK...${NC}"
    
    # Make gradlew executable
    chmod +x gradlew
    
    # Try to build
    if ./gradlew assembleDebug; then
        echo -e "${GREEN}✅ APK build successful!${NC}"
        
        # Find the APK
        APK_PATH=$(find . -name "*.apk" -type f | head -n1)
        
        if [ -n "$APK_PATH" ]; then
            # Copy to releases directory
            mkdir -p releases
            cp "$APK_PATH" "releases/ai-assistant-pro-v1.0.0.apk"
            
            echo -e "${GREEN}📱 APK created: releases/ai-assistant-pro-v1.0.0.apk${NC}"
            
            # Get APK info
            APK_SIZE=$(du -h "releases/ai-assistant-pro-v1.0.0.apk" | cut -f1)
            echo -e "${GREEN}📊 APK size: $APK_SIZE${NC}"
            
            return 0
        else
            echo -e "${RED}❌ APK file not found after build${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ APK build failed${NC}"
        echo -e "${YELLOW}💡 This is likely due to missing Android SDK${NC}"
        echo -e "${YELLOW}   The source code is complete and ready for Android Studio${NC}"
        return 1
    fi
}

# Create source distribution
create_source_dist() {
    echo -e "${BLUE}📦 Creating source distribution...${NC}"
    
    # Create a ZIP of the source code
    zip -r "releases/ai-assistant-pro-source-v1.0.0.zip" . \
        -x "*.git*" "build/*" "app/build/*" "*.DS_Store" "releases/*" "*.apk" \
        > /dev/null
    
    echo -e "${GREEN}✅ Source distribution created: releases/ai-assistant-pro-source-v1.0.0.zip${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting build process...${NC}"
    
    check_prerequisites
    clean_build
    
    # Try to build APK
    if build_apk; then
        echo -e "${GREEN}🎉 Build completed successfully!${NC}"
        echo -e "${GREEN}📱 Ready-to-install APK: releases/ai-assistant-pro-v1.0.0.apk${NC}"
    else
        echo -e "${YELLOW}⚠️  APK build failed, but source code is ready${NC}"
        echo -e "${YELLOW}   Users can build APK using Android Studio${NC}"
    fi
    
    create_source_dist
    
    echo ""
    echo -e "${BLUE}📋 Distribution files created:${NC}"
    ls -la releases/
    
    echo ""
    echo -e "${GREEN}🚀 Ready for GitHub release!${NC}"
    echo -e "${GREEN}   Upload files from releases/ directory${NC}"
    echo -e "${GREEN}   Users can download APK or build from source${NC}"
}

# Run main function
main
#!/bin/bash

# AI Assistant Pro - Build and Install Script
# This script builds the Android app and optionally installs it on a connected device

set -e

echo "🤖 AI Assistant Pro - Android Build Script"
echo "=========================================="

# Check if Android SDK is available
if ! command -v adb &> /dev/null; then
    echo "❌ Android SDK not found. Please install Android SDK and add it to PATH."
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
./gradlew clean

# Build debug APK
echo "🔨 Building debug APK..."
./gradlew assembleDebug

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    APK_PATH="app/build/outputs/apk/debug/app-debug.apk"
    
    if [ -f "$APK_PATH" ]; then
        echo "📱 APK created at: $APK_PATH"
        
        # Check for connected devices
        DEVICE_COUNT=$(adb devices | grep -c "device$")
        
        if [ $DEVICE_COUNT -gt 0 ]; then
            echo "📱 Found $DEVICE_COUNT connected device(s)"
            
            # Ask user if they want to install
            read -p "Do you want to install the APK on connected device? (y/n): " -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "📲 Installing APK..."
                adb install -r "$APK_PATH"
                
                if [ $? -eq 0 ]; then
                    echo "✅ Installation successful!"
                    echo "🚀 You can now launch AI Assistant Pro on your device"
                    
                    # Optional: Launch the app
                    read -p "Do you want to launch the app now? (y/n): " -n 1 -r
                    echo
                    
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        adb shell am start -n com.aiassistant.pro/.ui.MainActivity
                        echo "🎉 App launched!"
                    fi
                else
                    echo "❌ Installation failed"
                    exit 1
                fi
            fi
        else
            echo "📱 No devices connected. Connect a device and enable USB debugging to install."
            echo "📦 APK is ready for manual installation: $APK_PATH"
        fi
    else
        echo "❌ APK not found at expected location"
        exit 1
    fi
else
    echo "❌ Build failed"
    exit 1
fi

echo "🎉 Build process completed!"
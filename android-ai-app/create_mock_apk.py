#!/usr/bin/env python3
"""
Create a mock APK file structure for demonstration
This creates a placeholder APK that shows the project structure
"""

import zipfile
import os

def create_mock_apk():
    """Create a mock APK file with proper structure"""
    apk_path = "releases/ai-assistant-pro-v1.0.0.apk"
    
    # Create a ZIP file (APK is essentially a ZIP)
    with zipfile.ZipFile(apk_path, 'w', zipfile.ZIP_DEFLATED) as apk:
        # Add Android manifest
        manifest_content = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.aiassistant.pro"
    android:versionCode="1"
    android:versionName="1.0.0">
    
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    
    <application
        android:name=".AIAssistantApplication"
        android:label="AI Assistant Pro"
        android:icon="@mipmap/ic_launcher">
        
        <activity
            android:name=".ui.MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        
    </application>
</manifest>'''
        apk.writestr("AndroidManifest.xml", manifest_content)
        
        # Add classes.dex (compiled code)
        apk.writestr("classes.dex", b"DEX\n035\x00" + b"\x00" * 100)
        
        # Add resources
        apk.writestr("resources.arsc", b"AAPT" + b"\x00" * 50)
        
        # Add META-INF files
        apk.writestr("META-INF/MANIFEST.MF", "Manifest-Version: 1.0\nCreated-By: AI Assistant Pro Builder\n")
        apk.writestr("META-INF/CERT.SF", "Signature-Version: 1.0\nCreated-By: AI Assistant Pro Builder\n")
        apk.writestr("META-INF/CERT.RSA", b"\x30\x82" + b"\x00" * 50)
        
        # Add app info
        info_content = """
AI Assistant Pro v1.0.0
========================

This is a demonstration APK showing the project structure.

Features:
- 14 AI assistants in one app
- Beautiful Material Design 3 UI
- Floating window functionality
- Privacy-first approach
- Modern Android architecture

To build the actual APK:
1. Open project in Android Studio
2. Run: ./gradlew assembleDebug
3. Find APK in app/build/outputs/apk/debug/

For installation instructions, see INSTALLATION.md
"""
        apk.writestr("assets/app_info.txt", info_content)
    
    # Get file size
    size_mb = os.path.getsize(apk_path) / (1024 * 1024)
    print(f"Created mock APK: {apk_path} ({size_mb:.2f} MB)")
    print("This is a demonstration file showing APK structure.")
    print("To build the actual APK, use Android Studio with the source code.")

if __name__ == "__main__":
    create_mock_apk()
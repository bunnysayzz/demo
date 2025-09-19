# AppleAI Update System

This document provides a comprehensive guide to the AppleAI update system, which allows users to seamlessly update their application directly from the menu bar.

## Overview

The AppleAI update system consists of several components:

1. **UpdateManager.swift** - The core Swift class that handles the update process
2. **S3 Bucket** - Where update packages and appcast.xml are stored
3. **Appcast.xml** - An XML file that describes available updates
4. **Update Pipeline** - Scripts for building, packaging, and deploying updates

## How It Works

1. The app periodically checks for updates by downloading the appcast.xml file from S3
2. If a newer version is available, the user is notified and can choose to update
3. The update is downloaded, verified, and installed
4. The app is restarted with the new version

## Components

### UpdateManager.swift

This is the core Swift class that handles the update process. It:

- Checks for updates by downloading and parsing the appcast.xml file
- Displays update information to the user
- Downloads and verifies update packages
- Installs updates and restarts the app

### S3 Bucket

The S3 bucket (`appleai-updates`) stores:

- Update packages (zip files containing the app)
- The appcast.xml file that describes available updates

### Appcast.xml

This XML file follows the Sparkle framework format and contains:

- Version information
- Release notes
- Download URLs
- File sizes and checksums

Example:
```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>AppleAI Updates</title>
        <description>Most recent changes with links to updates</description>
        <language>en</language>
        <item>
            <title>Version 1.1.1</title>
            <description>
                <![CDATA[
                    <h2>New Features in 1.1.1:</h2>
                    <ul>
                        <li>Enhanced update system with improved reliability</li>
                        <li>Better error handling and logging</li>
                        <li>Fixed version verification issues</li>
                        <li>Improved UI responsiveness</li>
                    </ul>
                ]]>
            </description>
            <pubDate>Mon, 10 Jun 2025 12:00:00 +0000</pubDate>
            <enclosure
                url="https://appleai-updates.s3.amazonaws.com/AppleAI-1.1.1.zip"
                sparkle:version="1.1.1"
                sparkle:shortVersionString="1.1.1"
                length="2960268"
                type="application/octet-stream"
            />
            <sparkle:minimumSystemVersion>11.0</sparkle:minimumSystemVersion>
        </item>
    </channel>
</rss>
```

## Utility Scripts

### update_pipeline.sh

This script handles the entire update pipeline:

1. Builds the app with the specified version
2. Packages the app into a zip file
3. Creates a proper appcast.xml file
4. Uploads both to S3
5. Tests the update mechanism

Usage:
```bash
./update_pipeline.sh -v VERSION [-m MODE]
  -v VERSION    Version number (e.g. 1.1.1)
  -m MODE       Mode: upload (default), build, test
```

Examples:
```bash
# Build and upload version 1.1.1
./update_pipeline.sh -v 1.1.1

# Just build version 1.1.1 without uploading
./update_pipeline.sh -v 1.1.1 -m build

# Test the update mechanism
./update_pipeline.sh -v 1.1.1 -m test
```

### verify_update_system.sh

This script checks all components of the update system to ensure they're properly configured:

- Verifies S3 bucket configuration
- Validates appcast.xml structure
- Checks local app version
- Verifies UpdateManager implementation

Usage:
```bash
./verify_update_system.sh
```

### downgrade_for_testing.sh

This script downgrades the installed app to version 1.0 for testing the update system:

- Backs up the current app
- Sets version to 1.0 in Info.plist
- Builds and installs the app
- Launches the app for testing

Usage:
```bash
./downgrade_for_testing.sh
```

## Troubleshooting

If updates are failing, check the following:

1. **S3 Bucket Access**: Ensure the S3 bucket is properly configured with public read access
2. **Appcast.xml Format**: Validate the appcast.xml file for proper XML syntax
3. **URL Configuration**: Verify the URLs in UpdateManager.swift match the actual S3 bucket
4. **Version Numbers**: Make sure version numbers are consistent across Info.plist and appcast.xml
5. **App Permissions**: Check that the app has proper permissions to install updates

To get detailed logs, run the app from Terminal:
```bash
/Applications/AppleAI.app/Contents/MacOS/AppleAI
```

## Best Practices

1. **Version Numbering**: Use semantic versioning (MAJOR.MINOR.PATCH)
2. **Testing**: Always test updates on a development machine before deploying
3. **Backup**: Create backups before deploying updates
4. **Release Notes**: Provide clear and detailed release notes
5. **Incremental Updates**: Prefer small, incremental updates over large ones

## Security Considerations

1. **Code Signing**: Ensure all updates are properly code signed
2. **HTTPS**: Use HTTPS for all download URLs
3. **Verification**: Verify downloaded packages before installation
4. **User Consent**: Always get user consent before installing updates 
#!/bin/bash
set -e

# Configuration
S3_BUCKET="appleai-updates"
VERSION=$1
BUILD_DIR="/Users/mdazharuddin/Library/Developer/Xcode/DerivedData/AppleAI-gqezyuepbbvlvadpplvaetqtdqxn/Build/Products/Release"
APP_PATH="${BUILD_DIR}/AppleAI.app"
ZIP_NAME="AppleAI-${VERSION}.zip"

# Check if version was provided
if [ -z "$VERSION" ]; then
    echo "❌ Error: Version number required"
    echo "Usage: $0 <version>"
    echo "Example: $0 1.1.1"
    exit 1
fi

# Create directory for uploads if it doesn't exist
mkdir -p "$(dirname "$0")"

# Check if the app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: App not found at $APP_PATH"
    echo "Build the app first using xcodebuild or the build_and_install.sh script"
    exit 1
fi

echo "🔍 Checking current app version..."
PLIST_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist")

if [ "$PLIST_VERSION" != "$VERSION" ]; then
    echo "⚠️ Warning: Version mismatch. App is $PLIST_VERSION but uploading as $VERSION"
    read -p "Continue anyway? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "❌ Upload cancelled"
        exit 1
    fi
fi

# Create zip package
echo "📦 Creating zip package..."
cd "$BUILD_DIR" || exit 1
zip -r "$(dirname "$0")/$ZIP_NAME" AppleAI.app
echo "✅ Created $(dirname "$0")/$ZIP_NAME"

# Get file size for appcast
FILE_SIZE=$(stat -f%z "$(dirname "$0")/$ZIP_NAME")

# Create appcast.xml
echo "📝 Creating appcast.xml..."
cat > "$(dirname "$0")/appcast.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Apple AI Changelog</title>
        <description>Most recent changes with links to updates</description>
        <language>en</language>
        <item>
            <title>Version ${VERSION}</title>
            <description>
                <![CDATA[
                    <h2>New Features in ${VERSION}:</h2>
                    <ul>
                        <li>Enhanced update system with improved reliability</li>
                        <li>Real-time update progress tracking</li>
                        <li>Better error handling and retry mechanism</li>
                        <li>Improved UI responsiveness</li>
                        <li>Various bug fixes and performance improvements</li>
                    </ul>
                ]]>
            </description>
            <pubDate>$(date -R)</pubDate>
            <enclosure
                url="https://${S3_BUCKET}.s3.amazonaws.com/${ZIP_NAME}"
                sparkle:version="${VERSION}"
                sparkle:shortVersionString="${VERSION}"
                length="${FILE_SIZE}"
                type="application/octet-stream"
            />
            <sparkle:minimumSystemVersion>11.0</sparkle:minimumSystemVersion>
        </item>
    </channel>
</rss>
EOF
echo "✅ Created appcast.xml"

# Upload to S3
echo "☁️ Uploading files to S3..."
aws s3 cp "$(dirname "$0")/$ZIP_NAME" "s3://${S3_BUCKET}/" || { echo "❌ Failed to upload zip file"; exit 1; }
aws s3 cp "$(dirname "$0")/appcast.xml" "s3://${S3_BUCKET}/" || { echo "❌ Failed to upload appcast.xml"; exit 1; }

echo "✅ Update ${VERSION} successfully uploaded to S3"
echo "🚀 Your users can now update to version ${VERSION}" 
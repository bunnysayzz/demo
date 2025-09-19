# GitHub Release Instructions

To create the GitHub release for testing the update system:

1. Go to: https://github.com/bunnysayzz/AppleAI-update/releases/new

2. Create a release with these settings:
   - **Tag**: v1.1.1 (select the existing tag)
   - **Title**: AppleAI 1.1.1
   - **Description**:
     ```
     Release version 1.1.1 with improved update system using GitHub releases.

     ## Changes
     - Switched from AWS S3 to GitHub releases for updates
     - Improved reliability and performance
     - Fixed various bugs
     ```

3. Upload these files:
   - `/Users/mdazharuddin/AppleAI update/release_artifacts/AppleAI-1.1.1.zip`
   - `/Users/mdazharuddin/AppleAI update/appcast.xml`

4. Click "Publish release"

After publishing:
1. Make the appcast.xml accessible at: `https://github.com/bunnysayzz/AppleAI-update/releases/latest/download/appcast.xml`
2. The app should be able to download from: `https://github.com/bunnysayzz/AppleAI-update/releases/download/v1.1.1/AppleAI-1.1.1.zip` 
# 📱 AI Assistant Pro - Android Installation Guide

## 🚀 Quick Installation

### Method 1: Download APK (Recommended)
1. **Download the APK** from the [Releases](https://github.com/your-username/ai-assistant-pro-android/releases) page
2. **Enable Unknown Sources**:
   - Go to Settings > Security (or Privacy)
   - Enable "Install from Unknown Sources" or "Allow from this source"
3. **Install the APK**:
   - Tap the downloaded APK file
   - Follow the installation prompts
   - Grant necessary permissions when asked

### Method 2: Build from Source
1. **Prerequisites**:
   - Android Studio Arctic Fox or later
   - Android SDK API 26+
   - Git installed

2. **Clone and Build**:
   ```bash
   git clone https://github.com/your-username/ai-assistant-pro-android.git
   cd ai-assistant-pro-android
   ./build_and_install.sh
   ```

## 📋 Required Permissions

The app will request these permissions:

### Essential Permissions
- **Internet** - Required for AI service communication
- **Network State** - Check connectivity status

### Optional Permissions (requested when needed)
- **System Alert Window** - For floating window functionality
- **Storage/Media** - For file uploads to AI services
- **Camera** - For AI services that support image input
- **Microphone** - For voice input features
- **Notifications** - For important app notifications

## ⚙️ First-Time Setup

### 1. Launch the App
- Find "AI Assistant Pro" in your app drawer
- Tap to open the app

### 2. Grant Permissions
- **Allow internet access** (automatic)
- **Grant overlay permission** for floating window (optional)
- **Allow storage access** for file uploads (when needed)

### 3. Configure Settings
- Open Settings from the bottom navigation
- **Choose your theme** (Light/Dark/System)
- **Select visible AI models** (show/hide specific services)
- **Configure API keys** (optional, for enhanced features)

### 4. Enable Floating Window (Optional)
- Go to Settings > General
- Toggle "Floating Window" on
- Grant overlay permission when prompted
- Add Quick Settings tile for easy access

## 🎯 Usage Tips

### Getting Started
1. **Home Screen**: Browse available AI services
2. **Tap any service** to start chatting
3. **Switch services** using the dropdown in chat
4. **Use floating window** for multitasking

### Power User Features
- **Quick Settings tile**: Add from notification panel
- **Share content**: Share text/images from other apps
- **Voice input**: Enable in settings for supported services
- **File uploads**: Use paperclip icon in supported services

## 🔧 Troubleshooting

### App Won't Install
- **Check Android version**: Requires Android 8.0+ (API 26)
- **Enable Unknown Sources**: Must be enabled for APK installation
- **Clear download cache**: Clear Downloads app cache and retry
- **Sufficient storage**: Ensure 100MB+ free space

### Floating Window Issues
- **Grant overlay permission**: Settings > Apps > Special Access > Display over other apps
- **Disable battery optimization**: Settings > Battery > App optimization
- **Check Android version**: Some features require Android 8.0+

### WebView Problems
- **Update Android System WebView**: From Google Play Store
- **Clear app data**: Settings > Apps > AI Assistant Pro > Storage > Clear Data
- **Check internet connection**: Ensure stable internet access
- **Try different AI service**: Some services may be temporarily unavailable

### Performance Issues
- **Restart the app**: Close completely and reopen
- **Clear cache**: Settings > Apps > AI Assistant Pro > Storage > Clear Cache
- **Free up RAM**: Close other apps to free memory
- **Update Android**: Ensure latest Android version

## 🔒 Privacy & Security

### Data Handling
- **No data collection**: App doesn't collect personal data
- **Direct communication**: All chats go directly to AI service providers
- **Local storage**: Preferences stored securely on device
- **API keys**: Encrypted and stored locally only

### Permissions Usage
- **Internet**: Only for AI service communication
- **Storage**: Only when you choose to upload files
- **Camera/Microphone**: Only when you use voice/camera features
- **Overlay**: Only for floating window functionality

## 📞 Support

### Need Help?
- **Check this guide** for common solutions
- **Open an issue** on GitHub for bugs
- **Read the documentation** in README.md
- **Check FAQ** in the app settings

### Reporting Issues
Include this information:
- Android version
- Device model
- App version
- Steps to reproduce
- Error messages (if any)

## 🎉 Enjoy AI Assistant Pro!

You now have access to 14 powerful AI assistants in one beautiful Android app:
- ChatGPT, Claude, Copilot, Perplexity, DeepSeek, Grok
- Mistral, Gemini, Pi, Blackbox, Meta AI, Zhipu AI
- MCP Chat, and custom Ask Apple AI

**Happy chatting! 🤖✨**
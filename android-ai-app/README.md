# AI Assistant Pro - Android

A beautiful, fully-featured Android app that brings multiple AI assistants together in one streamlined interface. This is the Android companion to the macOS Apple AI Pro app, featuring the same powerful functionality with a native Material Design interface.

![AI Assistant Pro](https://img.shields.io/badge/Platform-Android-green.svg)
![API Level](https://img.shields.io/badge/API-26+-brightgreen.svg)
![Kotlin](https://img.shields.io/badge/Language-Kotlin-blue.svg)
![Jetpack Compose](https://img.shields.io/badge/UI-Jetpack%20Compose-orange.svg)

## ✨ Features

### 🤖 Multiple AI Services
- **ChatGPT** - OpenAI's conversational AI assistant
- **Claude** - Anthropic's helpful, harmless, and honest AI assistant
- **GitHub Copilot** - Microsoft's AI-powered coding assistant
- **Perplexity AI** - AI-powered search and research assistant
- **DeepSeek** - Advanced AI model for coding and reasoning
- **Grok** - xAI's witty and rebellious AI assistant
- **Mistral AI** - European AI assistant focused on efficiency
- **Google Gemini** - Google's most capable AI model
- **Pi AI** - Personal AI companion by Inflection AI
- **Blackbox AI** - AI coding assistant for developers
- **Meta AI** - Meta's AI assistant powered by Llama
- **Zhipu AI** - Chinese AI model with strong reasoning capabilities
- **MCP Chat** - Model Context Protocol enabled chat interface

### 🎨 Beautiful Material Design UI
- **Dynamic theming** with Material You support (Android 12+)
- **Light/Dark theme** support with system integration
- **Smooth animations** and transitions throughout the app
- **Responsive design** that works on phones and tablets
- **Edge-to-edge** display with proper insets handling

### 🪟 Floating Window Support
- **System overlay** floating window for quick AI access
- **Always-on-top** functionality for multitasking
- **Resizable and movable** floating window
- **Quick Settings tile** for instant access
- **Minimizable** floating window with compact mode

### ⚙️ Comprehensive Settings
- **Model visibility** controls - show/hide specific AI services
- **Theme customization** - light, dark, or system theme
- **API key management** - secure local storage for API keys
- **Privacy controls** - analytics and data collection preferences
- **Feature toggles** - enable/disable specific functionality

### 🔧 Advanced Features
- **WebView integration** with modern web standards support
- **File upload** support for compatible AI services
- **Voice input** capabilities for supported services
- **Screenshot capture** functionality
- **Session persistence** - maintains context across app restarts
- **Keyboard shortcuts** and accessibility support

### 🔒 Privacy-First Design
- **No data collection** - all chats go directly to AI service providers
- **Local storage** - preferences and API keys stored securely on device
- **Transparent permissions** - only request necessary permissions
- **Open source** - full source code available for review

## 📱 Screenshots

### Home Screen
Beautiful grid layout showcasing all available AI services with dynamic colors and service information.

### Chat Interface
Full-featured chat interface with WebView integration, service switching, and file upload support.

### Settings
Comprehensive settings screen with model visibility controls, theme options, and privacy settings.

### Floating Window
System overlay floating window that can be accessed from anywhere in Android.

## 🛠️ Technical Details

### Architecture
- **MVVM Architecture** with ViewModels and StateFlow
- **Dependency Injection** with Hilt
- **Jetpack Compose** for modern, declarative UI
- **DataStore** for preferences and settings persistence
- **Coroutines** for asynchronous operations

### Technologies Used
- **Kotlin** - Primary development language
- **Jetpack Compose** - Modern UI toolkit
- **Material Design 3** - Design system and components
- **Hilt** - Dependency injection framework
- **WebView** - Web content rendering
- **DataStore** - Data persistence
- **Coroutines & Flow** - Asynchronous programming
- **Accompanist** - Compose utilities and extensions

### Requirements
- **Android 8.0 (API 26)** or higher
- **4GB RAM** recommended for optimal performance
- **Internet connection** for AI service access
- **Overlay permission** for floating window functionality

## 🚀 Installation

### From APK
1. Download the latest APK from the [Releases](https://github.com/yourusername/ai-assistant-pro-android/releases) page
2. Enable "Install from Unknown Sources" in Android settings
3. Install the APK file
4. Grant necessary permissions when prompted

### From Source
1. Clone this repository
2. Open in Android Studio Arctic Fox or later
3. Build and run the project
4. Or generate a signed APK for distribution

## 📋 Permissions

The app requests the following permissions:

- **INTERNET** - Required for AI service communication
- **ACCESS_NETWORK_STATE** - Check network connectivity
- **SYSTEM_ALERT_WINDOW** - Floating window functionality
- **READ_EXTERNAL_STORAGE** - File uploads to AI services
- **CAMERA** - Camera access for supported AI services
- **RECORD_AUDIO** - Voice input for supported AI services
- **POST_NOTIFICATIONS** - Show important notifications

## ⚙️ Configuration

### API Keys
Configure API keys for enhanced functionality:
- **Gemini API Key** - Get from [ai.google.dev](https://ai.google.dev)
- **OpenAI API Key** - Get from [platform.openai.com](https://platform.openai.com)
- **Anthropic API Key** - Get from [console.anthropic.com](https://console.anthropic.com)

### Floating Window Setup
1. Enable "Display over other apps" permission
2. Toggle floating window in app settings
3. Use Quick Settings tile for instant access

## 🎯 Usage Tips

- **Swipe between services** in the chat interface for quick switching
- **Long press** service cards on home screen for quick actions
- **Use the floating window** for multitasking with AI assistance
- **Enable voice input** for hands-free AI interaction
- **Customize model visibility** to show only your preferred AI services

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup
1. Clone the repository
2. Open in Android Studio
3. Build the project
4. Run tests with `./gradlew test`
5. Submit pull requests for review

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by the macOS Apple AI Pro app
- Built with love using Jetpack Compose and Material Design
- Thanks to all AI service providers for their amazing platforms
- Community contributors and testers

## 🔗 Links

- [Apple AI Pro (macOS)](https://github.com/bunnysayzz/appleai) - Original macOS version
- [Material Design 3](https://m3.material.io/) - Design system
- [Jetpack Compose](https://developer.android.com/jetpack/compose) - UI toolkit

## 📞 Support

If you encounter any issues or have questions:
- Open an issue on GitHub
- Check the documentation
- Join our community discussions

---

**AI Assistant Pro** - Bringing the power of multiple AI assistants to your Android device with a beautiful, native interface.
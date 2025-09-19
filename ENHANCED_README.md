# Apple AI Pro - Enhanced Edition

A polished, professional macOS menu bar application that provides seamless access to multiple AI assistants in a single, lightweight interface. Inspired by modern macOS design principles and optimized for productivity.

## ✨ Enhanced Features

### 🎨 Modern Design System
- **Native macOS Integration**: Follows Apple's Human Interface Guidelines
- **Comprehensive Theme System**: Light/Dark/Auto modes with 12 accent colors
- **Smooth Animations**: Respects accessibility preferences (reduce motion)
- **Visual Hierarchy**: Clear, consistent typography and spacing

### 🤖 AI Assistant Hub
- **Multiple AI Services**: ChatGPT, Claude, Copilot, Perplexity, Gemini, and more
- **Quick Switching**: Instant access to different AI assistants
- **Session Persistence**: Maintains conversation state across app launches
- **Custom Models**: Support for additional AI services

### ⚙️ Advanced Preferences
- **Appearance Customization**: Choose themes and accent colors
- **Model Management**: Show/hide AI services as needed
- **API Key Management**: Secure storage for enhanced features
- **Privacy Controls**: Transparent data handling information
- **Keyboard Shortcuts**: Customizable global hotkeys

### 🔒 Privacy-First Design
- **Local Storage**: All preferences stored on your Mac
- **Direct Communication**: Requests go directly to AI providers
- **No Data Collection**: We don't collect or transmit your data
- **Microphone Control**: Automatic audio management for voice features

## 🚀 Key Improvements

### Architecture Enhancements
- **Modular Design**: Clean separation of concerns
- **Theme Management**: Centralized styling system
- **Session Management**: Comprehensive state persistence
- **Performance Optimization**: Efficient memory and resource usage

### User Experience
- **Enhanced Menu Bar**: Better icon design and status indicators
- **Improved Chat Interface**: Modern, responsive design
- **Better Accessibility**: VoiceOver support and keyboard navigation
- **Smooth Interactions**: Polished animations and transitions

### Technical Features
- **WebView Caching**: Efficient web view management
- **Memory Management**: Optimized resource usage
- **Error Handling**: Robust error recovery
- **Auto-Updates**: Seamless update system (when available)

## 📋 System Requirements

- **macOS**: 11.0 (Big Sur) or later
- **Architecture**: Universal (Apple Silicon & Intel)
- **Memory**: 4GB RAM recommended
- **Storage**: 50MB available space

## 🛠 Installation

### Option 1: Direct Download
1. Download the latest release from [GitHub Releases](https://github.com/bunnysayzz/AppleAI/releases)
2. Unzip the downloaded file
3. Move `Apple AI.app` to your Applications folder
4. Launch the app - it will appear in your menu bar

### Option 2: Build from Source
1. Clone the repository:
   ```bash
   git clone https://github.com/bunnysayzz/AppleAI.git
   ```
2. Open `AppleAI.xcodeproj` in Xcode
3. Build and run the project

## 🎯 Usage

### Basic Usage
1. **Launch**: The app appears as an icon in your menu bar
2. **Click**: Left-click to open the main chat window
3. **Right-click**: Access the context menu for quick actions
4. **Switch Services**: Use the service buttons at the top of the chat window

### Keyboard Shortcuts
- **Toggle Window**: `⌘E` (customizable)
- **Screenshot**: `⌥D` (captures area and copies to clipboard)
- **Preferences**: `⌘,`

### Advanced Features
- **Pin Window**: Use the pin button to keep the window always on top
- **Position Pinning**: Use the map pin to save window position
- **Theme Switching**: Access via Preferences → Appearance
- **API Keys**: Configure in Preferences → Tools for enhanced features

## ⚙️ Configuration

### Appearance Settings
- **Theme Mode**: Light, Dark, or Auto (follows system)
- **Accent Color**: Choose from 12 color options
- **Visual Effects**: Enable/disable vibrant backgrounds
- **Motion**: Reduce animations for accessibility

### Model Management
- **Show/Hide Services**: Customize which AI assistants appear
- **Service Order**: Automatically ordered by usage
- **Custom Services**: Add your own AI service URLs

### Privacy Settings
- **Data Handling**: Review how your data is processed
- **Microphone**: Control voice feature permissions
- **Screenshots**: Local capture with clipboard integration

## 🔧 Development

### Architecture Overview
```
AppleAI/
├── Managers/           # Core business logic
│   ├── ThemeManager    # Appearance and styling
│   ├── SessionManager  # State persistence
│   ├── MenuBarManager  # Menu bar integration
│   └── WebViewCache    # Web view management
├── Views/              # UI components
│   ├── Components/     # Reusable UI elements
│   └── Preferences/    # Settings interface
└── Models/             # Data structures
```

### Key Components

#### ThemeManager
Centralized theme and appearance management with support for:
- Light/Dark/Auto appearance modes
- 12 accent color options
- Accessibility preferences
- Real-time theme switching

#### SessionManager
Comprehensive session persistence including:
- Per-service state management
- Usage statistics and analytics
- Data export/import capabilities
- Automatic cleanup and optimization

#### WebViewCache
Efficient web view management featuring:
- Lazy loading and caching
- Memory optimization
- Cross-service state preservation
- Enhanced security controls

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes following the existing code style
4. Add appropriate documentation
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Apple**: For the excellent macOS development frameworks
- **AI Providers**: ChatGPT, Claude, Copilot, Perplexity, and others
- **Community**: For feedback, bug reports, and feature suggestions
- **Open Source**: Built with various open-source components

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/bunnysayzz/AppleAI/issues)
- **Discussions**: [GitHub Discussions](https://github.com/bunnysayzz/AppleAI/discussions)
- **Website**: [macbunny.co](https://macbunny.co)
- **Email**: Contact through the website

## 🔄 Changelog

### Version 2.2.0 (Enhanced Edition)
- ✨ Complete UI overhaul with modern design system
- 🎨 Comprehensive theme management (Light/Dark/Auto + 12 accent colors)
- 📊 Enhanced session persistence and analytics
- 🔒 Improved privacy controls and transparency
- ⚡ Performance optimizations and memory management
- ♿ Better accessibility support
- 🛠 Advanced preferences with better organization
- 🎯 Refined user experience and interactions

### Previous Versions
See [CHANGELOG.md](CHANGELOG.md) for complete version history.

---

**Apple AI Pro** - Your gateway to the world of AI, designed for macOS.
import SwiftUI
import Combine
import Foundation
import AVFoundation
import AppKit
import WebKit
import Carbon.HIToolbox
import ServiceManagement

/// Enhanced preferences view with modern design and comprehensive theme support
struct EnhancedPreferencesView: View {
    @State private var selectedSection: PreferencesSection = .appearance
    @StateObject private var preferences = PreferencesManager.shared
    @StateObject private var theme = ThemeManager.shared
    @StateObject private var launchManager = LaunchAtLoginManager()
    
    // API Keys
    @State private var geminiAPIKey: String = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
    @State private var chatgptAPIKey: String = UserDefaults.standard.string(forKey: "chatgptApiKey") ?? ""
    @State private var showingAPIKeyInfo = false
    
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        HStack(spacing: 0) {
            // Enhanced Sidebar
            sidebar
            
            // Main Content Area
            mainContent
        }
        .frame(width: 680, height: 520)
        .themeBackground(.primary)
        .themeAware()
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            // App Header
            appHeader
            
            // Section Navigation
            sectionNavigation
            
            Spacer()
            
            // Footer Links
            footerLinks
        }
        .frame(width: 200)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .themeBackground(.secondary)
        .overlay(
            Rectangle()
                .fill(theme.separatorColor.opacity(0.3))
                .frame(width: 1),
            alignment: .trailing
        )
    }
    
    private var appHeader: some View {
        HStack(spacing: 12) {
            Image("AILogos/appleai")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple AI Pro")
                    .font(.system(size: 16, weight: .semibold))
                    .themeForegroundColor(.primary)
                
                Text(versionString)
                    .font(.system(size: 12))
                    .themeForegroundColor(.secondary)
            }
        }
        .padding(.bottom, 8)
    }
    
    private var sectionNavigation: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(PreferencesSection.allCases) { section in
                sectionButton(for: section)
            }
        }
    }
    
    private func sectionButton(for section: PreferencesSection) -> some View {
        Button(action: { 
            withAnimation(theme.standardSpringAnimation) {
                selectedSection = section
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 16)
                
                Text(section.displayName)
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedSection == section ? theme.currentAccentColor.opacity(0.15) : Color.clear)
            )
            .foregroundColor(
                selectedSection == section ? theme.currentAccentColor : theme.primaryTextColor
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: 8) {
            footerLinkButton("GitHub", systemImage: "chevron.left.slash.chevron.right") {
                openURL(URL(string: "https://github.com/bunnysayzz/AppleAI.git")!)
            }
            
            footerLinkButton("More Apps", systemImage: "app.badge") {
                openURL(URL(string: "https://macbunny.co")!)
            }
        }
    }
    
    private func footerLinkButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(theme.currentAccentColor)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Section Header
            sectionHeader
            
            // Section Content
            ScrollView(.vertical, showsIndicators: false) {
                sectionContent
                    .padding(24)
            }
            .themeBackground(.primary)
        }
    }
    
    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedSection.displayName)
                    .font(.system(size: 20, weight: .semibold))
                    .themeForegroundColor(.primary)
                
                if let subtitle = selectedSection.subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .themeForegroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .themeBackground(.primary)
        .overlay(
            Rectangle()
                .fill(theme.separatorColor.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .appearance:
            AppearanceSection()
        case .general:
            GeneralSection()
        case .models:
            ModelsSection()
        case .tools:
            ToolsSection()
        case .privacy:
            PrivacySection()
        case .about:
            AboutSection()
        }
    }
    
    // MARK: - Computed Properties
    
    private var versionString: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        
        if let short = shortVersion, let build = buildVersion {
            return short == build ? "v\(short)" : "v\(short) (\(build))"
        }
        return "Unknown Version"
    }
}

// MARK: - Preferences Sections

enum PreferencesSection: String, CaseIterable, Identifiable {
    case appearance = "Appearance"
    case general = "General"
    case models = "Models"
    case tools = "Tools"
    case privacy = "Privacy"
    case about = "About"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .appearance: return "paintbrush"
        case .general: return "gearshape"
        case .models: return "square.grid.2x2"
        case .tools: return "wrench.and.screwdriver"
        case .privacy: return "hand.raised"
        case .about: return "info.circle"
        }
    }
    
    var subtitle: String? {
        switch self {
        case .appearance: return "Customize the look and feel of Apple AI"
        case .general: return "Configure general app behavior and settings"
        case .models: return "Manage which AI models appear in the interface"
        case .tools: return "Set up API keys and keyboard shortcuts"
        case .privacy: return "Review privacy settings and data handling"
        case .about: return "Information about Apple AI and support"
        }
    }
}

// MARK: - Section Views

struct AppearanceSection: View {
    @StateObject private var theme = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Appearance Mode
            ModernCard.simple {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader("Appearance", subtitle: "Choose how Apple AI looks")
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(ThemeManager.AppearanceMode.allCases, id: \.self) { mode in
                            appearanceModeButton(mode)
                        }
                    }
                }
            }
            
            // Accent Color
            ModernCard.simple {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader("Accent Color", subtitle: "Personalize your interface")
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(ThemeManager.AccentColorOption.allCases, id: \.self) { color in
                            accentColorButton(color)
                        }
                    }
                }
            }
            
            // Visual Effects
            ModernCard.simple {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader("Visual Effects", subtitle: "Enhance the interface with effects")
                    
                    VStack(spacing: 12) {
                        settingToggle(
                            "Vibrant Backgrounds",
                            subtitle: "Use translucent backgrounds for a modern look",
                            isOn: $theme.useVibrantBackgrounds
                        )
                        
                        settingToggle(
                            "Reduce Motion",
                            subtitle: "Minimize animations for accessibility",
                            isOn: $theme.reduceMotion
                        )
                    }
                }
            }
        }
    }
    
    private func appearanceModeButton(_ mode: ThemeManager.AppearanceMode) -> some View {
        Button(action: { theme.appearanceMode = mode }) {
            VStack(spacing: 8) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 24))
                    .foregroundColor(theme.appearanceMode == mode ? theme.currentAccentColor : theme.secondaryTextColor)
                
                Text(mode.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.appearanceMode == mode ? theme.currentAccentColor : theme.primaryTextColor)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.appearanceMode == mode ? theme.currentAccentColor.opacity(0.1) : theme.secondaryBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.appearanceMode == mode ? theme.currentAccentColor : theme.separatorColor, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func accentColorButton(_ color: ThemeManager.AccentColorOption) -> some View {
        Button(action: { theme.accentColor = color }) {
            Circle()
                .fill(color.color)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(theme.accentColor == color ? Color.white : Color.clear, lineWidth: 2)
                )
                .overlay(
                    Circle()
                        .stroke(theme.separatorColor, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func settingToggle(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .themeForegroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .themeForegroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .toggleStyle(SwitchToggleStyle())
        }
        .padding(.vertical, 4)
    }
}

struct GeneralSection: View {
    @StateObject private var preferences = PreferencesManager.shared
    @StateObject private var launchManager = LaunchAtLoginManager()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // App Behavior
            ModernCard.simple {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader("App Behavior", subtitle: "Configure how Apple AI behaves")
                    
                    VStack(spacing: 12) {
                        settingToggle(
                            "Always on Top",
                            subtitle: "Keep the window above other applications",
                            systemImage: "pin.fill",
                            isOn: $preferences.alwaysOnTop
                        )
                        
                        settingToggle(
                            "Launch at Login",
                            subtitle: "Automatically start Apple AI when you log in",
                            systemImage: "arrow.up.circle.fill",
                            isOn: Binding(
                                get: { launchManager.isEnabled },
                                set: { _ in launchManager.toggle() }
                            )
                        )
                    }
                }
            }
            
            // Window Behavior
            ModernCard.simple {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader("Window Behavior", subtitle: "Control window positioning and behavior")
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ThemeManager.shared.currentAccentColor)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pin Position")
                                    .font(.system(size: 14, weight: .medium))
                                    .themeForegroundColor(.primary)
                                
                                Text("Use the map pin button in the title bar to save the window position. When enabled, the window will always open at the saved location.")
                                    .font(.system(size: 12))
                                    .themeForegroundColor(.secondary)
                            }
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ThemeManager.shared.currentAccentColor)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Always on Top")
                                    .font(.system(size: 14, weight: .medium))
                                    .themeForegroundColor(.primary)
                                
                                Text("Use the push pin button in the title bar to keep the window above other apps. This doesn't affect the position.")
                                    .font(.system(size: 12))
                                    .themeForegroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func settingToggle(_ title: String, subtitle: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
                .foregroundColor(ThemeManager.shared.currentAccentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .themeForegroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .themeForegroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .toggleStyle(SwitchToggleStyle())
        }
        .padding(.vertical, 4)
    }
}

struct ModelsSection: View {
    @StateObject private var preferences = PreferencesManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ModernCard.simple {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(
                        "AI Models",
                        subtitle: "Choose which AI assistants appear in the interface",
                        actionTitle: "Reset All"
                    ) {
                        preferences.resetToDefaults()
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        ForEach(aiServices) { service in
                            modelToggleCard(for: service)
                        }
                    }
                }
            }
        }
    }
    
    private func modelToggleCard(for service: AIService) -> some View {
        let isVisible = Binding<Bool>(
            get: { preferences.isModelVisible(service.name) },
            set: { preferences.setModelVisibility($0, for: service.name) }
        )
        
        return ModernCard(
            style: .secondary,
            padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
            cornerRadius: 12,
            hasShadow: false
        ) {
            HStack(spacing: 12) {
                Toggle(isOn: isVisible) {
                    HStack(spacing: 12) {
                        Image(service.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(service.color)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(service.name)
                                .font(.system(size: 14, weight: .medium))
                                .themeForegroundColor(.primary)
                            
                            if service.isCustom {
                                StatusBadge("Custom", style: .accent, size: .small)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .toggleStyle(CheckboxToggleStyle())
            }
        }
    }
}

struct ToolsSection: View {
    @StateObject private var preferences = PreferencesManager.shared
    @State private var geminiAPIKey: String = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
    @State private var chatgptAPIKey: String = UserDefaults.standard.string(forKey: "chatgptApiKey") ?? ""
    @State private var showingAPIKeyInfo = false
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // API Keys
            ModernCard.simple {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader("API Keys", subtitle: "Configure API keys for enhanced features")
                    
                    VStack(spacing: 16) {
                        apiKeyField(
                            title: "Gemini API Key",
                            key: $geminiAPIKey,
                            placeholder: "Enter your Gemini API key",
                            helpURL: "https://ai.google.dev/"
                        ) {
                            let trimmed = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            UserDefaults.standard.set(trimmed, forKey: "geminiApiKey")
                            GeminiAPIManager.shared.updateApiKey(trimmed)
                        }
                        
                        apiKeyField(
                            title: "ChatGPT API Key",
                            key: $chatgptAPIKey,
                            placeholder: "Enter your OpenAI API key",
                            helpURL: "https://platform.openai.com/api-keys"
                        ) {
                            let trimmed = chatgptAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            UserDefaults.standard.set(trimmed, forKey: "chatgptApiKey")
                            GeminiAPIManager.shared.updateChatGPTApiKey(trimmed)
                        }
                    }
                }
            }
            
            // Keyboard Shortcuts
            ModernCard.simple {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader("Keyboard Shortcuts", subtitle: "Customize global shortcuts")
                    
                    VStack(spacing: 12) {
                        shortcutRow(
                            title: "Toggle Window",
                            current: preferences.currentHotKeyDisplayString(),
                            onReset: { preferences.resetHotKeyToDefault() }
                        )
                        
                        shortcutRow(
                            title: "Screenshot Capture",
                            current: "⌥D",
                            description: "Select an area and copy screenshot to clipboard"
                        )
                    }
                }
            }
        }
    }
    
    private func apiKeyField(
        title: String,
        key: Binding<String>,
        placeholder: String,
        helpURL: String,
        onApply: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .themeForegroundColor(.primary)
                
                Spacer()
                
                ModernButton.icon("link", style: .ghost, size: .small) {
                    openURL(URL(string: helpURL)!)
                }
            }
            
            HStack(spacing: 8) {
                SecureField(placeholder, text: key)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                ModernButton.primary("Apply", size: .small, action: onApply)
                
                ModernButton.secondary("Clear", size: .small) {
                    key.wrappedValue = ""
                    onApply()
                }
            }
        }
    }
    
    private func shortcutRow(
        title: String,
        current: String,
        description: String? = nil,
        onReset: (() -> Void)? = nil
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .themeForegroundColor(.primary)
                
                if let description = description {
                    Text(description)
                        .font(.system(size: 12))
                        .themeForegroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(current)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ThemeManager.shared.secondaryBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                if let onReset = onReset {
                    ModernButton.icon("arrow.counterclockwise", style: .ghost, size: .small, action: onReset)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PrivacySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ModernCard.accent {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 24))
                            .foregroundColor(ThemeManager.shared.currentAccentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Privacy Matters")
                                .font(.system(size: 16, weight: .semibold))
                                .themeForegroundColor(.primary)
                            
                            Text("Apple AI is designed with privacy in mind")
                                .font(.system(size: 14))
                                .themeForegroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
            
            ModernCard.simple {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader("Data Handling", subtitle: "How your data is processed and stored")
                    
                    VStack(alignment: .leading, spacing: 12) {
                        privacyPoint(
                            icon: "externaldrive.connected.to.line.below",
                            title: "Local Storage",
                            description: "All settings and preferences are stored locally on your Mac. We don't collect or transmit your configuration data."
                        )
                        
                        privacyPoint(
                            icon: "arrow.right.circle",
                            title: "Direct Communication",
                            description: "When you use AI services, your requests go directly to that provider (OpenAI, Anthropic, Google, etc.) — not through our servers."
                        )
                        
                        privacyPoint(
                            icon: "mic.slash",
                            title: "Microphone Control",
                            description: "Microphone access is only used for voice features in AI platforms. We automatically stop recording when you're done."
                        )
                        
                        privacyPoint(
                            icon: "camera.viewfinder",
                            title: "Screenshot Privacy",
                            description: "Screenshots are captured locally and copied to your clipboard. They're never uploaded or processed by Apple AI."
                        )
                    }
                }
            }
        }
    }
    
    private func privacyPoint(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ThemeManager.shared.currentAccentColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .themeForegroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 12))
                    .themeForegroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AboutSection: View {
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // App Information
            ModernCard.simple {
                HStack(spacing: 16) {
                    Image("AILogos/appleai")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Apple AI Pro")
                            .font(.system(size: 24, weight: .bold))
                            .themeForegroundColor(.primary)
                        
                        Text(versionString)
                            .font(.system(size: 16))
                            .themeForegroundColor(.secondary)
                        
                        Text("A powerful AI assistant hub for macOS")
                            .font(.system(size: 14))
                            .themeForegroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            // Support & Links
            ModernCard.simple {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader("Support & Links", subtitle: "Get help and learn more")
                    
                    VStack(spacing: 12) {
                        supportLink(
                            title: "GitHub Repository",
                            subtitle: "View source code and report issues",
                            icon: "chevron.left.slash.chevron.right",
                            url: "https://github.com/bunnysayzz/AppleAI.git"
                        )
                        
                        supportLink(
                            title: "Developer Website",
                            subtitle: "Discover more Mac applications",
                            icon: "app.badge",
                            url: "https://macbunny.co"
                        )
                        
                        supportLink(
                            title: "Report Issues",
                            subtitle: "Get help with problems or bugs",
                            icon: "exclamationmark.bubble",
                            url: "https://macbunny.co/appleai"
                        )
                    }
                }
            }
            
            // Copyright
            HStack {
                Spacer()
                Text("© 2024 MacBunny. All rights reserved.")
                    .font(.system(size: 12))
                    .themeForegroundColor(.tertiary)
                Spacer()
            }
            .padding(.top, 16)
        }
    }
    
    private func supportLink(title: String, subtitle: String, icon: String, url: String) -> some View {
        Button(action: { openURL(URL(string: url)!) }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ThemeManager.shared.currentAccentColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .themeForegroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .themeForegroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .themeForegroundColor(.tertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var versionString: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        
        if let short = shortVersion, let build = buildVersion {
            return short == build ? "Version \(short)" : "Version \(short) (\(build))"
        }
        return "Unknown Version"
    }
}

#Preview {
    EnhancedPreferencesView()
        .frame(width: 680, height: 520)
}
import SwiftUI
import Combine
import Foundation
import AVFoundation
import AppKit
import WebKit
import Carbon.HIToolbox
import ServiceManagement

// ProTag view for marking pro features
struct ProTag: View {
    var isSmall: Bool = false
    
    var body: some View {
        Text("PRO")
            .font(.system(size: isSmall ? 8 : 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, isSmall ? 4 : 6)
            .padding(.vertical, isSmall ? 1 : 2)
            .background(LinearGradient(gradient: Gradient(colors: [Color(#colorLiteral(red: 0.8, green: 0.4, blue: 0.2, alpha: 1)), Color(#colorLiteral(red: 1, green: 0.4, blue: 0.2, alpha: 1))]), startPoint: .leading, endPoint: .trailing))
            .cornerRadius(3)
            .shadow(color: Color.black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
    }
}

private enum PreferencesSection: String, CaseIterable, Identifiable {
    case general = "General"
    case models = "Models"
    case tools = "Tools"
    case about = "About"
    var id: String { rawValue }
}

struct PreferencesView: View {
    @State private var selection: PreferencesSection = .general
    @State private var geminiAPIKey: String = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
    @State private var showingAPIKeyInfo = false
    @StateObject private var preferences = PreferencesManager.shared
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image("AILogos/appleai")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .cornerRadius(4)
                    Text("Apple AI Pro")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.top, 12)
                
                ForEach(PreferencesSection.allCases) { item in
                    Button(action: { selection = item }) {
                        HStack(spacing: 8) {
                            Image(systemName: iconName(for: item))
                                .font(.system(size: 12, weight: .semibold))
                            Text(item.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selection == item ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                SVGFooterView()
                    .frame(height: 26)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 6)
            }
            .frame(width: 150)
            .background(Color(.controlBackgroundColor))
            .overlay(Rectangle().fill(Color.black.opacity(0.06)).frame(width: 1), alignment: .trailing)
            
            // Content
        VStack(spacing: 0) {
                // Header
                HStack {
                    Text(selection.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.windowBackgroundColor))
                .overlay(Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1), alignment: .bottom)
                
                // Section content
                Group {
                    switch selection {
                    case .general:
                        GeneralSection()
                    case .models:
                        ModelsSection()
                    case .tools:
                        ToolsSection()
                    case .about:
                        AboutSection()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.windowBackgroundColor))
            }
        }
        .frame(width: 520, height: 420)
        .background(Color(.windowBackgroundColor))
    }
    
    private func iconName(for section: PreferencesSection) -> String {
        switch section {
        case .general: return "gearshape"
        case .models: return "square.grid.2x2"
        case .tools: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }
}

private struct FooterLinks: View {
    var body: some View {
        HStack(spacing: 10) {
            Link(destination: URL(string: "https://github.com/bunnysayzz/AppleAI.git")!) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left.slash.chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                    Text("GitHub")
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Link(destination: URL(string: "https://macbunny.co")!) {
                HStack(spacing: 4) {
                    Image(systemName: "app.badge")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Mac Apps")
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .foregroundColor(.accentColor)
    }
}

private struct SectionContainer<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(12)
        }
    }
}

private struct GeneralSection: View {
    @StateObject private var preferences = PreferencesManager.shared
    @StateObject private var launchAtLoginManager = LaunchAtLoginManager()
    
    var body: some View {
        SectionContainer {
                    PreferenceSection(title: "General") {
                            AlwaysOnTopSettingRow(isOn: $preferences.alwaysOnTop)
                            LaunchAtLoginSettingRow(manager: launchAtLoginManager)
                        }
            PreferenceSection(title: "Window Pinning") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentColor)
                        Text("Pin Position: Toggle the mappin button in the title bar to make the window always open at the saved screen spot. Move or resize while pinned to update the saved position. This applies only while position pinning is enabled.")
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentColor)
                        Text("Always on Top: Use the pushpin button in the title bar to keep the window above other apps. This does not change the position.")
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

struct AlwaysOnTopSettingRow: View {
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "pin.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Always on Top")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("Keep the window above other apps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct LaunchAtLoginSettingRow: View {
    @ObservedObject var manager: LaunchAtLoginManager
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Launch at Login")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("Automatically start Apple AI Pro when you log in")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { manager.isEnabled },
                set: { _ in manager.toggle() }
            ))
            .toggleStyle(SwitchToggleStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .onAppear {
            manager.checkCurrentStatus()
        }
    }
}

private struct KeyboardShortcutsSection: View {
    @StateObject private var preferences = PreferencesManager.shared
    @State private var pendingKeyCode: UInt32? = nil
    @State private var pendingModifiers: UInt32? = nil
    
    private let allowedModifiers: [(label: String, value: UInt32)] = [
        ("⌘ Command", UInt32(cmdKey)),
        ("⌥ Option", UInt32(optionKey)),
        ("⌃ Control", UInt32(controlKey))
    ]
    private let allowedLetters: [String] = ["L", "B", "G", "Y", "U"]
    
    @State private var selectedModifierIndex: Int = 0
    @State private var selectedLetterIndex: Int = 0
    @State private var errorText: String? = nil
    
    var body: some View {
        PreferenceSection(title: "Keyboard Shortcuts") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Toggle Window")
                        .font(.system(size: 12))
                    Spacer()
                    Text(displayText())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 10) {
                    Picker("Modifier", selection: $selectedModifierIndex) {
                        ForEach(0..<allowedModifiers.count, id: \.self) { i in
                            Text(allowedModifiers[i].label).tag(i)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                    
                    Picker("Letter", selection: $selectedLetterIndex) {
                        ForEach(0..<allowedLetters.count, id: \.self) { i in
                            Text(allowedLetters[i]).tag(i)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 100)
                    
                    Button(action: { applySelection() }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                            .padding(6)
                            .background(Color.green.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .help("Apply")
                    .buttonStyle(PlainButtonStyle())
                    
                            Button(action: {
                        preferences.resetHotKeyToDefault()
                        pendingKeyCode = nil
                        pendingModifiers = nil
                        errorText = nil
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color.gray.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .help("Default")
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(minHeight: 28)
                
                if let err = errorText {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                } else {
                    Text("Choose a Command/Option/Control + letter (5 options). Reserved combos are blocked.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            let cfg = preferences.getHotKeyConfig()
            if cfg.modifiers & UInt32(cmdKey) != 0 { selectedModifierIndex = 0 }
            else if cfg.modifiers & UInt32(optionKey) != 0 { selectedModifierIndex = 1 }
            else { selectedModifierIndex = 2 }
            if let letter = PreferencesManager.keyCodeToLetter(cfg.keyCode), let idx = allowedLetters.firstIndex(of: letter) {
                selectedLetterIndex = idx
            } else {
                selectedLetterIndex = 0
            }
        }
    }
    
    private func applySelection() {
        errorText = nil
        let mods = allowedModifiers[selectedModifierIndex].value
        let letter = allowedLetters[selectedLetterIndex]
        guard let key = PreferencesManager.letterToKeyCode(letter) else { return }
        
        if mods & UInt32(cmdKey) != 0 {
            let reserved: Set<String> = ["Q","W","M","C","V","X","Z","A","S","P","O","N","T"]
            if reserved.contains(letter) {
                errorText = "This Command+\(letter) is reserved. Try another."
                return
            }
        }
        
        pendingKeyCode = key
        pendingModifiers = mods
        if let k = pendingKeyCode, let m = pendingModifiers {
            preferences.setHotKey(keyCode: k, modifiers: m)
            pendingKeyCode = nil
            pendingModifiers = nil
        }
    }
    
    private func displayText() -> String {
        if let k = pendingKeyCode, let m = pendingModifiers {
            return PreferencesManager.displayString(forKeyCode: k, modifiers: m)
        }
        let cfg = preferences.getHotKeyConfig()
        return PreferencesManager.displayString(forKeyCode: cfg.keyCode, modifiers: cfg.modifiers)
    }
}

private struct ModelsSection: View {
    @StateObject private var preferences = PreferencesManager.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
                    PreferenceSection(title: "Show AI Models", showReset: true, resetAction: {
                        preferences.resetToDefaults()
                    }) {
                        AdaptiveModelGrid(services: aiServices)
            }
        }
        .padding(12)
    }
}

private struct ToolsSection: View {
    @StateObject private var preferences = PreferencesManager.shared
    @State private var geminiAPIKey: String = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
    @State private var chatgptAPIKey: String = UserDefaults.standard.string(forKey: "chatgptApiKey") ?? ""
    @State private var showingAPIKeyInfo = false
    @Environment(\.openURL) private var openURL
    var body: some View {
        SectionContainer {
            // API Keys (enabled in Pro)
            PreferenceSection(title: "API Keys") {
                VStack(alignment: .leading, spacing: 10) {
                    // Gemini key row
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("Gemini API Key")
                                .font(.system(size: 12))
                            Spacer()
                            Button(action: { showingAPIKeyInfo = true }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .popover(isPresented: $showingAPIKeyInfo) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("API Key Information")
                                        .font(.headline)
                                    Text("Use a provider API key from the service you choose. You can get a Gemini key by:")
                                    Text("1. Visit ai.google.dev")
                                    Text("2. Sign up for Google AI Studio")
                                    Text("3. Create an API key")
                                    Button("Get Gemini API Key") { if let url = URL(string: "https://ai.google.dev/") { openURL(url) } }
                                        .padding(.top, 5)
                                }
                                .padding()
                                .frame(width: 300)
                            }
                        }
                        HStack(spacing: 6) {
                            FocusableTextField("Enter Gemini API key", text: $geminiAPIKey)
                                .frame(height: 24)
                                .padding(.horizontal, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
                            Button(action: {
                                let trimmed = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                                UserDefaults.standard.set(trimmed, forKey: "geminiApiKey")
                                DispatchQueue.main.async { GeminiAPIManager.shared.updateApiKey(trimmed) }
                            }) {
                                HStack(spacing: 4) { Image(systemName: "checkmark.circle.fill").font(.system(size: 10, weight: .bold)); Text("Apply").font(.system(size: 11, weight: .medium)) }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Button(action: {
                                geminiAPIKey = ""
                                UserDefaults.standard.removeObject(forKey: "geminiApiKey")
                                DispatchQueue.main.async { GeminiAPIManager.shared.updateApiKey("") }
                            }) {
                                HStack(spacing: 4) { Image(systemName: "trash").font(.system(size: 10, weight: .bold)); Text("Clear").font(.system(size: 11, weight: .medium)) }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // ChatGPT key row
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("ChatGPT API Key")
                                .font(.system(size: 12))
                            Spacer()
                            Button(action: {
                                if let url = URL(string: "https://platform.openai.com/api-keys") { openURL(url) }
                            }) {
                                HStack(spacing: 4) { Image(systemName: "link"); Text("Get Key") }
                                .font(.system(size: 11))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        HStack(spacing: 6) {
                            FocusableTextField("Enter ChatGPT API key", text: $chatgptAPIKey)
                                .frame(height: 24)
                                .padding(.horizontal, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
                            Button(action: {
                                let trimmed = chatgptAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                                UserDefaults.standard.set(trimmed, forKey: "chatgptApiKey")
                                DispatchQueue.main.async { GeminiAPIManager.shared.updateChatGPTApiKey(trimmed) }
                            }) {
                                HStack(spacing: 4) { Image(systemName: "checkmark.circle.fill").font(.system(size: 10, weight: .bold)); Text("Apply").font(.system(size: 11, weight: .medium)) }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Button(action: {
                                chatgptAPIKey = ""
                                UserDefaults.standard.removeObject(forKey: "chatgptApiKey")
                                DispatchQueue.main.async { GeminiAPIManager.shared.updateChatGPTApiKey("") }
                            }) {
                                HStack(spacing: 4) { Image(systemName: "trash").font(.system(size: 10, weight: .bold)); Text("Clear").font(.system(size: 11, weight: .medium)) }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
            // Keyboard Shortcuts moved here
            KeyboardShortcutsSection()
            
            // Compact tip: Screenshot capture shortcut
            PreferenceSection(title: "Screenshot Capture") {
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text("Press Option+D to select an area and copy the screenshot")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Text("⌥D")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.12))
                        )
                }
            }
        }
    }
}

private struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Card: Branding + Version + Privacy copy (no inner "About" header)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Image("AILogos/appleai")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple AI Pro")
                            .font(.system(size: 12, weight: .medium))
                        Text(aboutVersionString())
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Button(action: {
                            if let url = URL(string: "https://macbunny.co/appleai") { NSWorkspace.shared.open(url) }
                        }) {
                            Image(systemName: "exclamationmark.bubble")
                                .font(.system(size: 14, weight: .regular))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Report")
                        Button(action: {
                            if let url = URL(string: "https://github.com/bunnysayzz/AppleAI.git") { NSWorkspace.shared.open(url) }
                        }) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 14, weight: .regular))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Developer Profile")
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("We care about your privacy.")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Apple AI is a Mac app from MacBunny, designed to work locally whenever possible.")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    Text("We don’t collect your chats or usage data. When you choose a model, requests go directly to that provider (like OpenAI, Anthropic, or Google)—not to us.")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    Text("Permissions (like microphone or screen recording) are only requested when needed, and your settings are saved on your Mac.")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
            
            // Card: Links footer
            PreferenceSection(title: "Links") {
                VStack(spacing: 8) {
                    SVGFooterView()
                        .frame(height: 26)
                }
            }
        }
        .padding(12)
    }
    
    private func aboutVersionString() -> String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let short = shortVersion, let build = buildVersion {
            return short == build ? "Version \(short)" : "Version \(short) (\(build))"
        }
        return "Version Unknown"
    }
}

// Renders the provided SVG footer (GitHub + Mac Apps) using a lightweight WKWebView
private struct SVGFooterView: NSViewRepresentable {
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, navigationAction.navigationType == .linkActivated {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
            }
            return nil
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.loadHTMLString(html, baseURL: nil)
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsMagnification = false
        webView.configuration.suppressesIncrementalRendering = true
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) { }
    
    // Inline HTML & CSS corresponding to user's SVG footer
    private var html: String {
        """
        <!doctype html>
        <html>
        <head>
            <meta charset='utf-8'>
            <meta name='viewport' content='width=device-width,initial-scale=1'>
            <style>
                :root { color-scheme: light dark; }
                body { margin: 0; padding: 0; background: transparent; font-family: -apple-system, system-ui; }
                html, body { overflow: hidden; }
                *::-webkit-scrollbar { width: 0; height: 0; display: none; }
                .footer { display: flex; gap: 6px; align-items: center; padding: 0; white-space: nowrap; height: 22px; }
                .footer-link { display: inline-flex; align-items: center; gap: 3px; text-decoration: none; padding: 2px 6px; border-radius: 6px; height: 20px; }
                .footer-link:hover { background: rgba(127,127,127,0.10); }
                .icon { width: 12px; height: 12px; fill: currentColor; display: block; }
                .github-link { color: -webkit-link; }
                .mac-link { color: -webkit-link; }
                span { font-size: 10px; font-weight: 600; line-height: 1; display: inline-block; }
            </style>
        </head>
        <body>
            <div class="footer">
                <a href="https://github.com/bunnysayzz/AppleAI.git" target="_blank" class="footer-link github-link" rel="noopener noreferrer" style="align-items:center;">
                    <svg class="icon" viewBox="0 0 24 24" aria-hidden="true">
                        <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/>
                    </svg>
                    <span>GitHub</span>
                </a>
                <a href="https://macbunny.co" target="_blank" class="footer-link mac-link" rel="noopener noreferrer" style="align-items:center;">
                    <svg class="icon" viewBox="0 0 24 24" aria-hidden="true">
                        <path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"/>
                    </svg>
                    <span>Mac Apps</span>
                </a>
            </div>
        </body>
        </html>
        """
    }
}

// New adaptive grid layout for AI models that dynamically adjusts based on visible models
struct AdaptiveModelGrid: View {
    let services: [AIService]
    @StateObject private var preferences = PreferencesManager.shared
    
    // Computed property to get visible models
    private var visibleServices: [AIService] {
        return services.filter { preferences.isModelVisible($0.name) }
    }
    
    // Back to 2 columns for larger tiles, still fitting without scroll
    private var optimizedColumns: Int { 2 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Build two balanced columns while preserving order
            let leftColumn = services.enumerated().compactMap { $0.offset % 2 == 0 ? $0.element : nil }
            let rightColumn = services.enumerated().compactMap { $0.offset % 2 == 1 ? $0.element : nil }
            let rowCount = max(leftColumn.count, rightColumn.count)
            
            ForEach(0..<rowCount, id: \.self) { rowIndex in
                HStack(spacing: 10) {
                    if rowIndex < leftColumn.count {
                            EnhancedModelToggle(
                            service: leftColumn[rowIndex],
                                totalServices: services.count,
                                visibleCount: visibleServices.count
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                        Spacer().frame(maxWidth: .infinity)
                    }
                    if rowIndex < rightColumn.count {
                        EnhancedModelToggle(
                            service: rightColumn[rowIndex],
                            totalServices: services.count,
                            visibleCount: visibleServices.count
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Spacer().frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }
}

// Section title with content - more compact
struct PreferenceSection<Content: View>: View {
    let title: String
    var showReset: Bool = false
    var resetAction: (() -> Void)? = nil
    let content: Content
    
    init(title: String, showReset: Bool = false, resetAction: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.showReset = showReset
        self.resetAction = resetAction
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if showReset {
                    Button("Reset All", action: { resetAction?() })
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                }
            }
            
            content
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }
}

// Enhanced model toggle with dynamic sizing based on number of visible models
struct EnhancedModelToggle: View {
    let service: AIService
    let totalServices: Int
    let visibleCount: Int
    @StateObject private var preferences = PreferencesManager.shared
    
    // Larger comfortable sizes
    private var iconSize: CGFloat { 20 }
    private var fontSize: CGFloat { 13 }
    
    var body: some View {
        let isVisible = Binding<Bool>(
            get: { preferences.isModelVisible(service.name) },
            set: { preferences.setModelVisibility($0, for: service.name) }
        )
        
        HStack(spacing: 8) {
            Toggle(isOn: isVisible) {
                HStack(spacing: 8) {
                    Image(service.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .foregroundColor(service.color)
                    
                    Text(service.name)
                        .font(.system(size: fontSize))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
            }
            .toggleStyle(CheckboxToggleStyle())
            .controlSize(.small)
        }
        .padding(.vertical, 3)
    }
}

// Toggle row with consistent styling - more compact
struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var help: String? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.primary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .help(help ?? "")
                .controlSize(.mini)
        }
    }
}

// Shortcut display row - more compact
struct ShortcutRow: View {
    let action: String
    let shortcut: String
    
    var body: some View {
        HStack {
            Text(action)
                .font(.system(size: 12))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(shortcut)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                )
        }
    }
}

// Link button style
struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? Color.accentColor.opacity(0.7) : Color.accentColor)
            .contentShape(Rectangle())
    }
}

#Preview {
    PreferencesView()
}

// FocusableTextField - NSTextField wrapper for better keyboard handling
struct FocusableTextField: NSViewRepresentable {
    var placeholder: String
    @Binding var text: String
    
    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.stringValue = text
        textField.delegate = context.coordinator
        textField.bezelStyle = .roundedBezel
        textField.isBordered = true
        textField.focusRingType = .exterior
        textField.drawsBackground = true
        textField.isEditable = true
        textField.isSelectable = true
        textField.allowsEditingTextAttributes = false
        textField.backgroundColor = NSColor.textBackgroundColor
        textField.textColor = NSColor.textColor
        textField.font = NSFont.systemFont(ofSize: 13)
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        
        init(text: Binding<String>) {
            self._text = text
        }
        
        func controlTextDidChange(_ notification: Notification) {
            if let textField = notification.object as? NSTextField {
                text = textField.stringValue
            }
        }
    }
} 

// LaunchAtLoginManager - Utility class for managing launch at login (matches utilix)
class LaunchAtLoginManager: ObservableObject {
    @Published var isEnabled: Bool = false
    
    init() {
        checkCurrentStatus()
    }
    
    func checkCurrentStatus() {
        if #available(macOS 13.0, *) {
            isEnabled = SMAppService.mainApp.status == .enabled
        } else {
            isEnabled = isInLoginItems()
        }
    }
    
    func toggle() {
        if #available(macOS 13.0, *) {
            do {
                if isEnabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
                isEnabled.toggle()
            } catch {
                // Show a basic alert on failure
                let alert = NSAlert()
                alert.messageText = "Launch at Login Error"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        } else {
            if isEnabled { removeFromLoginItems() } else { addToLoginItems() }
        }
    }
    
    // MARK: - Legacy support (macOS 12 and earlier)
    private func isInLoginItems() -> Bool {
        guard let bundleId = Bundle.main.bundleIdentifier else { return false }
        let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)
        guard let loginItemsRef = loginItems?.takeRetainedValue() else { return false }
        let loginItemsArray = LSSharedFileListCopySnapshot(loginItemsRef, nil)
        guard let itemsArray = loginItemsArray?.takeRetainedValue() as? [LSSharedFileListItem] else { return false }
        for item in itemsArray {
            if let itemURL = LSSharedFileListItemCopyResolvedURL(item, 0, nil)?.takeRetainedValue() {
                if let itemBundle = Bundle(url: itemURL as URL), itemBundle.bundleIdentifier == bundleId {
                    return true
                }
            }
        }
        return false
    }
    
    private func addToLoginItems() {
        let appURL = Bundle.main.bundleURL
        let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)
        guard let loginItemsRef = loginItems?.takeRetainedValue() else { return }
        let result = LSSharedFileListInsertItemURL(
            loginItemsRef,
            kLSSharedFileListItemLast.takeRetainedValue(),
            nil,
            nil,
            appURL as CFURL,
            nil,
            nil
        )
        if result != nil { isEnabled = true }
    }
    
    private func removeFromLoginItems() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)
        guard let loginItemsRef = loginItems?.takeRetainedValue() else { return }
        let loginItemsArray = LSSharedFileListCopySnapshot(loginItemsRef, nil)
        guard let itemsArray = loginItemsArray?.takeRetainedValue() as? [LSSharedFileListItem] else { return }
        for item in itemsArray {
            if let itemURL = LSSharedFileListItemCopyResolvedURL(item, 0, nil)?.takeRetainedValue() {
                if let itemBundle = Bundle(url: itemURL as URL), itemBundle.bundleIdentifier == bundleId {
                    LSSharedFileListItemRemove(loginItemsRef, item)
                    isEnabled = false
                    return
                }
            }
        }
    }
} 
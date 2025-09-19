import SwiftUI
import Combine
import AppKit

/**
 * Comprehensive theme management system for AppleAI
 * 
 * This class provides centralized styling, accent colors, and appearance management
 * for the entire application. It follows macOS design guidelines and supports:
 * - Light/Dark/Auto appearance modes
 * - 12 accent color options including system default
 * - Accessibility features (reduce motion, high contrast)
 * - Real-time theme switching with smooth animations
 * - Persistent user preferences
 * 
 * Usage:
 * ```swift
 * @StateObject private var theme = ThemeManager.shared
 * 
 * // Apply theme-aware styling
 * someView.themeBackground(.primary)
 *         .themeForegroundColor(.accent)
 * ```
 */
@available(macOS 11.0, *)
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    // MARK: - Published Properties
    
    /// Current appearance mode (light/dark/auto)
    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
            applyAppearance()
        }
    }
    
    /// Current accent color
    @Published var accentColor: AccentColorOption {
        didSet {
            UserDefaults.standard.set(accentColor.rawValue, forKey: "accentColor")
            updateAccentColor()
        }
    }
    
    /// Whether to use vibrant backgrounds
    @Published var useVibrantBackgrounds: Bool {
        didSet {
            UserDefaults.standard.set(useVibrantBackgrounds, forKey: "useVibrantBackgrounds")
        }
    }
    
    /// Whether to reduce motion for accessibility
    @Published var reduceMotion: Bool {
        didSet {
            UserDefaults.standard.set(reduceMotion, forKey: "reduceMotion")
        }
    }
    
    /// Current effective appearance (resolved from auto mode)
    @Published private(set) var effectiveAppearance: NSAppearance.Name = .aqua
    
    // MARK: - Appearance Modes
    
    enum AppearanceMode: String, CaseIterable {
        case light = "light"
        case dark = "dark"
        case auto = "auto"
        
        var displayName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .auto: return "Auto"
            }
        }
        
        var systemImage: String {
            switch self {
            case .light: return "sun.max"
            case .dark: return "moon"
            case .auto: return "circle.lefthalf.filled"
            }
        }
    }
    
    // MARK: - Accent Colors
    
    enum AccentColorOption: String, CaseIterable {
        case system = "system"
        case blue = "blue"
        case purple = "purple"
        case pink = "pink"
        case red = "red"
        case orange = "orange"
        case yellow = "yellow"
        case green = "green"
        case mint = "mint"
        case teal = "teal"
        case cyan = "cyan"
        case indigo = "indigo"
        
        var displayName: String {
            switch self {
            case .system: return "System"
            case .blue: return "Blue"
            case .purple: return "Purple"
            case .pink: return "Pink"
            case .red: return "Red"
            case .orange: return "Orange"
            case .yellow: return "Yellow"
            case .green: return "Green"
            case .mint: return "Mint"
            case .teal: return "Teal"
            case .cyan: return "Cyan"
            case .indigo: return "Indigo"
            }
        }
        
        var color: Color {
            switch self {
            case .system: return .accentColor
            case .blue: return .blue
            case .purple: return .purple
            case .pink: return .pink
            case .red: return .red
            case .orange: return .orange
            case .yellow: return .yellow
            case .green: return .green
            case .mint: return Color(NSColor.systemMint)
            case .teal: return Color(NSColor.systemTeal)
            case .cyan: return Color(NSColor.systemCyan)
            case .indigo: return Color(NSColor.systemIndigo)
            }
        }
        
        var nsColor: NSColor {
            switch self {
            case .system: return .controlAccentColor
            case .blue: return .systemBlue
            case .purple: return .systemPurple
            case .pink: return .systemPink
            case .red: return .systemRed
            case .orange: return .systemOrange
            case .yellow: return .systemYellow
            case .green: return .systemGreen
            case .mint: return .systemMint
            case .teal: return .systemTeal
            case .cyan: return .systemCyan
            case .indigo: return .systemIndigo
            }
        }
    }
    
    // MARK: - Animation Durations
    
    var standardAnimationDuration: Double {
        reduceMotion ? 0.1 : 0.3
    }
    
    var fastAnimationDuration: Double {
        reduceMotion ? 0.05 : 0.15
    }
    
    var slowAnimationDuration: Double {
        reduceMotion ? 0.2 : 0.5
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load saved preferences
        let savedAppearance = UserDefaults.standard.string(forKey: "appearanceMode") ?? AppearanceMode.auto.rawValue
        self.appearanceMode = AppearanceMode(rawValue: savedAppearance) ?? .auto
        
        let savedAccentColor = UserDefaults.standard.string(forKey: "accentColor") ?? AccentColorOption.system.rawValue
        self.accentColor = AccentColorOption(rawValue: savedAccentColor) ?? .system
        
        self.useVibrantBackgrounds = UserDefaults.standard.bool(forKey: "useVibrantBackgrounds")
        self.reduceMotion = UserDefaults.standard.bool(forKey: "reduceMotion")
        
        // Set up system appearance monitoring
        setupAppearanceMonitoring()
        
        // Apply initial settings
        applyAppearance()
        updateAccentColor()
    }
    
    // MARK: - Appearance Management
    
    private func setupAppearanceMonitoring() {
        // Monitor system appearance changes
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(systemAppearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
        
        // Monitor accessibility changes
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: NSNotification.Name("com.apple.accessibility.api"),
            object: nil
        )
    }
    
    @objc private func systemAppearanceChanged() {
        if appearanceMode == .auto {
            DispatchQueue.main.async {
                self.applyAppearance()
            }
        }
    }
    
    @objc private func accessibilitySettingsChanged() {
        DispatchQueue.main.async {
            // Check for reduce motion changes
            let newReduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            if self.reduceMotion != newReduceMotion {
                self.reduceMotion = newReduceMotion
            }
        }
    }
    
    private func applyAppearance() {
        let targetAppearance: NSAppearance.Name
        
        switch appearanceMode {
        case .light:
            targetAppearance = .aqua
        case .dark:
            targetAppearance = .darkAqua
        case .auto:
            // Use system preference
            let systemAppearance = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
            targetAppearance = systemAppearance == "Dark" ? .darkAqua : .aqua
        }
        
        effectiveAppearance = targetAppearance
        
        // Apply to main app
        DispatchQueue.main.async {
            NSApp.appearance = NSAppearance(named: targetAppearance)
            
            // Notify observers
            NotificationCenter.default.post(
                name: Notification.Name("ThemeAppearanceChanged"),
                object: targetAppearance
            )
        }
    }
    
    private func updateAccentColor() {
        // Update system accent color if possible
        if accentColor != .system {
            // Note: Changing system accent color programmatically is limited
            // We'll rely on our color properties for UI elements
        }
        
        // Notify observers
        NotificationCenter.default.post(
            name: Notification.Name("ThemeAccentColorChanged"),
            object: accentColor
        )
    }
    
    // MARK: - Color Utilities
    
    /// Get primary text color for current theme
    var primaryTextColor: Color {
        Color(NSColor.labelColor)
    }
    
    /// Get secondary text color for current theme
    var secondaryTextColor: Color {
        Color(NSColor.secondaryLabelColor)
    }
    
    /// Get tertiary text color for current theme
    var tertiaryTextColor: Color {
        Color(NSColor.tertiaryLabelColor)
    }
    
    /// Get primary background color for current theme
    var primaryBackgroundColor: Color {
        Color(NSColor.windowBackgroundColor)
    }
    
    /// Get secondary background color for current theme
    var secondaryBackgroundColor: Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    /// Get separator color for current theme
    var separatorColor: Color {
        Color(NSColor.separatorColor)
    }
    
    /// Get current accent color
    var currentAccentColor: Color {
        accentColor.color
    }
    
    /// Get vibrant background material
    var vibrantBackgroundMaterial: NSVisualEffectView.Material {
        if #available(macOS 10.14, *) {
            return effectiveAppearance == .darkAqua ? .hudWindow : .popover
        } else {
            return .popover
        }
    }
    
    // MARK: - Animation Utilities
    
    /// Get standard spring animation
    var standardSpringAnimation: Animation {
        reduceMotion ? 
            .linear(duration: fastAnimationDuration) :
            .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)
    }
    
    /// Get fast spring animation
    var fastSpringAnimation: Animation {
        reduceMotion ? 
            .linear(duration: 0.05) :
            .spring(response: 0.2, dampingFraction: 0.9, blendDuration: 0)
    }
    
    /// Get smooth ease animation
    var smoothEaseAnimation: Animation {
        .easeInOut(duration: standardAnimationDuration)
    }
    
    // MARK: - Reset Methods
    
    /// Reset all theme settings to defaults
    func resetToDefaults() {
        appearanceMode = .auto
        accentColor = .system
        useVibrantBackgrounds = false
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

// MARK: - Theme-Aware View Modifiers

/// View modifier that applies theme-aware styling
struct ThemeAware: ViewModifier {
    @ObservedObject private var theme = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .accentColor(theme.currentAccentColor)
            .animation(theme.standardSpringAnimation, value: theme.effectiveAppearance)
            .animation(theme.standardSpringAnimation, value: theme.accentColor)
    }
}

/// View modifier for theme-aware backgrounds
struct ThemeBackground: ViewModifier {
    @ObservedObject private var theme = ThemeManager.shared
    let style: BackgroundStyle
    
    enum BackgroundStyle {
        case primary
        case secondary
        case vibrant
    }
    
    func body(content: Content) -> some View {
        content
            .background(backgroundView)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            theme.primaryBackgroundColor
        case .secondary:
            theme.secondaryBackgroundColor
        case .vibrant:
            if theme.useVibrantBackgrounds {
                VisualEffectView(material: theme.vibrantBackgroundMaterial, blendingMode: .behindWindow)
            } else {
                theme.primaryBackgroundColor
            }
        }
    }
}

/// Visual effect view wrapper for SwiftUI
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - View Extensions

extension View {
    /// Apply theme-aware styling
    func themeAware() -> some View {
        modifier(ThemeAware())
    }
    
    /// Apply theme-aware background
    func themeBackground(_ style: ThemeBackground.BackgroundStyle = .primary) -> some View {
        modifier(ThemeBackground(style: style))
    }
    
    /// Apply theme-aware text color
    func themeForegroundColor(_ style: TextColorStyle = .primary) -> some View {
        foregroundColor(ThemeManager.shared.textColor(for: style))
    }
}

enum TextColorStyle {
    case primary
    case secondary
    case tertiary
    case accent
}

extension ThemeManager {
    func textColor(for style: TextColorStyle) -> Color {
        switch style {
        case .primary: return primaryTextColor
        case .secondary: return secondaryTextColor
        case .tertiary: return tertiaryTextColor
        case .accent: return currentAccentColor
        }
    }
}
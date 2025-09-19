import SwiftUI
import AppKit

/// Modern card component with theme support and subtle animations
struct ModernCard<Content: View>: View {
    let content: Content
    let style: CardStyle
    let padding: EdgeInsets
    let cornerRadius: CGFloat
    let hasShadow: Bool
    let isInteractive: Bool
    let action: (() -> Void)?
    
    @State private var isHovered = false
    @ObservedObject private var theme = ThemeManager.shared
    
    init(
        style: CardStyle = .primary,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        cornerRadius: CGFloat = 12,
        hasShadow: Bool = true,
        isInteractive: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.style = style
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.hasShadow = hasShadow
        self.isInteractive = isInteractive
        self.action = action
    }
    
    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cardContent
            }
        }
        .onHover { hovering in
            if isInteractive || action != nil {
                withAnimation(theme.fastSpringAnimation) {
                    isHovered = hovering
                }
            }
        }
    }
    
    @ViewBuilder
    private var cardContent: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .overlay(borderOverlay)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowOffset
            )
            .scaleEffect(isHovered && isInteractive ? 1.02 : 1.0)
            .animation(theme.standardSpringAnimation, value: isHovered)
    }
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return theme.primaryBackgroundColor
        case .secondary:
            return theme.secondaryBackgroundColor
        case .accent:
            return theme.currentAccentColor.opacity(0.1)
        case .vibrant:
            return theme.useVibrantBackgrounds ? .clear : theme.primaryBackgroundColor
        }
    }
    
    @ViewBuilder
    private var borderOverlay: some View {
        if style != .vibrant {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(theme.separatorColor.opacity(0.3), lineWidth: 0.5)
        }
    }
    
    private var shadowColor: Color {
        guard hasShadow else { return .clear }
        return Color.black.opacity(theme.effectiveAppearance == .darkAqua ? 0.3 : 0.1)
    }
    
    private var shadowRadius: CGFloat {
        guard hasShadow else { return 0 }
        return isHovered && isInteractive ? 8 : 4
    }
    
    private var shadowOffset: CGFloat {
        guard hasShadow else { return 0 }
        return isHovered && isInteractive ? 4 : 2
    }
}

// MARK: - Card Styles

extension ModernCard {
    enum CardStyle {
        case primary    // Primary background color
        case secondary  // Secondary background color
        case accent     // Subtle accent color background
        case vibrant    // Uses visual effect view when enabled
    }
}

// MARK: - Convenience Initializers

extension ModernCard {
    /// Create a simple card with default styling
    static func simple<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> ModernCard<Content> {
        ModernCard(content: content)
    }
    
    /// Create an interactive card with hover effects
    static func interactive<Content: View>(
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> ModernCard<Content> {
        ModernCard(
            isInteractive: true,
            action: action,
            content: content
        )
    }
    
    /// Create a compact card with reduced padding
    static func compact<Content: View>(
        style: CardStyle = .primary,
        @ViewBuilder content: () -> Content
    ) -> ModernCard<Content> {
        ModernCard(
            style: style,
            padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
            cornerRadius: 8,
            content: content
        )
    }
    
    /// Create an accent-colored card
    static func accent<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> ModernCard<Content> {
        ModernCard(
            style: .accent,
            content: content
        )
    }
}

/// Section header component for grouping content
struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let action: (() -> Void)?
    let actionTitle: String?
    
    @ObservedObject private var theme = ThemeManager.shared
    
    init(
        _ title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryTextColor)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryTextColor)
                }
            }
            
            Spacer()
            
            if let action = action, let actionTitle = actionTitle {
                ModernButton.secondary(
                    actionTitle,
                    size: .small,
                    action: action
                )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
}

/// Divider component with theme support
struct ThemeDivider: View {
    let thickness: CGFloat
    let opacity: Double
    
    @ObservedObject private var theme = ThemeManager.shared
    
    init(thickness: CGFloat = 1, opacity: Double = 0.2) {
        self.thickness = thickness
        self.opacity = opacity
    }
    
    var body: some View {
        Rectangle()
            .fill(theme.separatorColor)
            .frame(height: thickness)
            .opacity(opacity)
    }
}

/// Loading indicator with theme support
struct ThemeLoadingIndicator: View {
    let size: CGFloat
    let lineWidth: CGFloat
    
    @State private var isAnimating = false
    @ObservedObject private var theme = ThemeManager.shared
    
    init(size: CGFloat = 20, lineWidth: CGFloat = 2) {
        self.size = size
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.8)
            .stroke(
                theme.currentAccentColor,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                theme.reduceMotion ? 
                    .linear(duration: 0.1) :
                    .linear(duration: 1).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

/// Badge component for status indicators
struct StatusBadge: View {
    let text: String
    let style: BadgeStyle
    let size: BadgeSize
    
    @ObservedObject private var theme = ThemeManager.shared
    
    init(_ text: String, style: BadgeStyle = .neutral, size: BadgeSize = .medium) {
        self.text = text
        self.style = style
        self.size = size
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: size.fontSize, weight: .medium))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(backgroundColor)
            .clipShape(Capsule())
    }
    
    private var foregroundColor: Color {
        switch style {
        case .neutral: return theme.primaryTextColor
        case .accent: return .white
        case .success: return .white
        case .warning: return .white
        case .error: return .white
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .neutral: return theme.secondaryBackgroundColor
        case .accent: return theme.currentAccentColor
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
    
    enum BadgeStyle {
        case neutral, accent, success, warning, error
    }
    
    enum BadgeSize {
        case small, medium, large
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 11
            case .large: return 12
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 10
            }
        }
        
        var verticalPadding: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return 3
            case .large: return 4
            }
        }
    }
}
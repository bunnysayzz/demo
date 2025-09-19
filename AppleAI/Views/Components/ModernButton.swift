import SwiftUI
import AppKit

/// Modern, theme-aware button component following macOS design guidelines
struct ModernButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    
    // Style properties
    let style: ButtonStyle
    let size: ButtonSize
    let isDestructive: Bool
    let isDisabled: Bool
    
    // State
    @State private var isHovered = false
    @State private var isPressed = false
    @ObservedObject private var theme = ThemeManager.shared
    
    init(
        _ title: String,
        systemImage: String? = nil,
        style: ButtonStyle = .primary,
        size: ButtonSize = .medium,
        isDestructive: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.size = size
        self.isDestructive = isDestructive
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: size.iconSpacing) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: size.iconSize, weight: .medium))
                }
                
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: size.fontSize, weight: size.fontWeight))
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(backgroundColor)
            .overlay(borderOverlay)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(theme.fastSpringAnimation, value: isPressed)
            .animation(theme.fastSpringAnimation, value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .onHover { hovering in
            withAnimation(theme.fastSpringAnimation) {
                isHovered = hovering
            }
        }
        .pressEvents(
            onPress: {
                withAnimation(theme.fastSpringAnimation) {
                    isPressed = true
                }
            },
            onRelease: {
                withAnimation(theme.fastSpringAnimation) {
                    isPressed = false
                }
            }
        )
        .help(title)
    }
    
    // MARK: - Computed Properties
    
    private var foregroundColor: Color {
        if isDisabled {
            return theme.tertiaryTextColor
        }
        
        switch style {
        case .primary:
            return isDestructive ? .white : .white
        case .secondary:
            return isDestructive ? .red : theme.primaryTextColor
        case .tertiary:
            return isDestructive ? .red : theme.currentAccentColor
        case .ghost:
            return isDestructive ? .red : theme.primaryTextColor
        }
    }
    
    private var backgroundColor: Color {
        if isDisabled {
            return theme.secondaryBackgroundColor.opacity(0.3)
        }
        
        let baseColor: Color
        switch style {
        case .primary:
            baseColor = isDestructive ? .red : theme.currentAccentColor
        case .secondary:
            baseColor = theme.secondaryBackgroundColor
        case .tertiary:
            baseColor = theme.currentAccentColor.opacity(0.1)
        case .ghost:
            baseColor = .clear
        }
        
        if isPressed {
            return baseColor.opacity(0.8)
        } else if isHovered {
            return baseColor.opacity(style == .ghost ? 0.1 : 1.0)
        } else {
            return baseColor
        }
    }
    
    @ViewBuilder
    private var borderOverlay: some View {
        if style == .secondary || style == .ghost {
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .stroke(
                    isDestructive ? .red : theme.separatorColor,
                    lineWidth: style == .ghost ? 0 : 1
                )
                .opacity(isDisabled ? 0.3 : 1.0)
        }
    }
}

// MARK: - Button Styles

extension ModernButton {
    enum ButtonStyle {
        case primary    // Filled with accent color
        case secondary  // Outlined with background
        case tertiary   // Subtle background with accent color
        case ghost      // No background, minimal styling
    }
    
    enum ButtonSize {
        case small
        case medium
        case large
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 11
            case .medium: return 13
            case .large: return 15
            }
        }
        
        var fontWeight: Font.Weight {
            switch self {
            case .small: return .medium
            case .medium: return .medium
            case .large: return .semibold
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 12
            case .large: return 16
            }
        }
        
        var verticalPadding: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            }
        }
        
        var iconSpacing: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }
    }
}

// MARK: - Convenience Initializers

extension ModernButton {
    /// Create a primary button
    static func primary(
        _ title: String,
        systemImage: String? = nil,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) -> ModernButton {
        ModernButton(
            title,
            systemImage: systemImage,
            style: .primary,
            size: size,
            action: action
        )
    }
    
    /// Create a secondary button
    static func secondary(
        _ title: String,
        systemImage: String? = nil,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) -> ModernButton {
        ModernButton(
            title,
            systemImage: systemImage,
            style: .secondary,
            size: size,
            action: action
        )
    }
    
    /// Create a destructive button
    static func destructive(
        _ title: String,
        systemImage: String? = nil,
        style: ButtonStyle = .secondary,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) -> ModernButton {
        ModernButton(
            title,
            systemImage: systemImage,
            style: style,
            size: size,
            isDestructive: true,
            action: action
        )
    }
    
    /// Create an icon-only button
    static func icon(
        _ systemImage: String,
        style: ButtonStyle = .ghost,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) -> ModernButton {
        ModernButton(
            "",
            systemImage: systemImage,
            style: style,
            size: size,
            action: action
        )
    }
}

// MARK: - Press Events Modifier

struct PressEvents: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void
    
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: .infinity,
                pressing: { pressing in
                    if pressing {
                        isPressed = true
                        onPress()
                    } else {
                        isPressed = false
                        onRelease()
                    }
                },
                perform: {}
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEvents(onPress: onPress, onRelease: onRelease))
    }
}
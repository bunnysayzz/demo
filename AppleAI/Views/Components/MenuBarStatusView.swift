import SwiftUI
import AppKit

/// Enhanced menu bar status view with theme integration and status indicators
struct MenuBarStatusView: NSViewRepresentable {
    @StateObject private var theme = ThemeManager.shared
    @State private var isActive = false
    @State private var hasNotification = false
    
    func makeNSView(context: Context) -> NSView {
        let view = StatusBarView()
        view.coordinator = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let statusView = nsView as? StatusBarView else { return }
        statusView.updateAppearance()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: MenuBarStatusView
        
        init(_ parent: MenuBarStatusView) {
            self.parent = parent
        }
    }
}

/// Custom NSView for the menu bar status item
class StatusBarView: NSView {
    weak var coordinator: MenuBarStatusView.Coordinator?
    private var iconLayer: CALayer?
    private var notificationBadge: CALayer?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        
        // Create the main icon layer
        setupIconLayer()
        
        // Create notification badge layer
        setupNotificationBadge()
        
        // Set initial size
        frame = NSRect(x: 0, y: 0, width: 22, height: 22)
    }
    
    private func setupIconLayer() {
        iconLayer = CALayer()
        guard let iconLayer = iconLayer else { return }
        
        // Load the menu bar icon
        if let iconImage = NSImage(named: "MenuBarIcon") {
            // Create a template version for better system integration
            let templateImage = iconImage.copy() as! NSImage
            templateImage.isTemplate = true
            
            iconLayer.contents = templateImage
            iconLayer.contentsGravity = .resizeAspect
        }
        
        layer?.addSublayer(iconLayer)
        updateIconLayout()
    }
    
    private func setupNotificationBadge() {
        notificationBadge = CALayer()
        guard let badge = notificationBadge else { return }
        
        badge.backgroundColor = NSColor.systemRed.cgColor
        badge.cornerRadius = 4
        badge.isHidden = true
        
        layer?.addSublayer(badge)
    }
    
    private func updateIconLayout() {
        guard let iconLayer = iconLayer else { return }
        
        let iconSize: CGFloat = 18
        let iconRect = NSRect(
            x: (bounds.width - iconSize) / 2,
            y: (bounds.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        
        iconLayer.frame = iconRect
        
        // Update notification badge position
        if let badge = notificationBadge {
            badge.frame = NSRect(
                x: iconRect.maxX - 6,
                y: iconRect.maxY - 6,
                width: 8,
                height: 8
            )
        }
    }
    
    override func layout() {
        super.layout()
        updateIconLayout()
    }
    
    func updateAppearance() {
        // Update appearance based on current theme
        let isDarkMode = ThemeManager.shared.effectiveAppearance == .darkAqua
        
        // Update icon color for better visibility
        if let iconLayer = iconLayer {
            iconLayer.opacity = isDarkMode ? 0.9 : 0.8
        }
        
        // Animate appearance changes
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        layer?.setNeedsDisplay()
        CATransaction.commit()
    }
    
    func showNotificationBadge(_ show: Bool) {
        guard let badge = notificationBadge else { return }
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        badge.isHidden = !show
        
        if show {
            badge.transform = CATransform3DMakeScale(0.1, 0.1, 1)
            CATransaction.setCompletionBlock {
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.2)
                badge.transform = CATransform3DIdentity
                CATransaction.commit()
            }
        }
        
        CATransaction.commit()
    }
    
    override func mouseDown(with event: NSEvent) {
        // Add subtle click feedback
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        iconLayer?.transform = CATransform3DMakeScale(0.9, 0.9, 1)
        CATransaction.setCompletionBlock {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.1)
            self.iconLayer?.transform = CATransform3DIdentity
            CATransaction.commit()
        }
        CATransaction.commit()
        
        super.mouseDown(with: event)
    }
}

/// Enhanced menu bar manager with better integration
extension MenuBarManager {
    /// Update the status item with enhanced styling
    func updateStatusItemAppearance() {
        guard let button = statusItem.button else { return }
        
        // Apply theme-aware styling
        if let iconImage = NSImage(named: "MenuBarIcon") {
            let templateImage = iconImage.copy() as! NSImage
            templateImage.isTemplate = true
            templateImage.size = NSSize(width: 18, height: 18)
            
            button.image = templateImage
            button.imagePosition = .imageOnly
            
            // Add subtle hover effect
            button.imageScaling = .scaleProportionallyUpOrDown
        }
        
        // Set accessibility information
        button.toolTip = "Apple AI - Click to open, right-click for menu"
        
        // Update appearance based on current theme
        if let appearance = NSAppearance(named: ThemeManager.shared.effectiveAppearance) {
            button.appearance = appearance
        }
    }
    
    /// Show a notification badge on the menu bar icon
    func showNotificationBadge(_ show: Bool = true) {
        // This would be implemented if we had a custom status bar view
        // For now, we can use the standard approach or implement later
    }
    
    /// Animate the menu bar icon for user feedback
    func animateStatusIcon() {
        guard let button = statusItem.button else { return }
        
        // Create a subtle pulse animation
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.0
        animation.toValue = 1.1
        animation.duration = 0.1
        animation.autoreverses = true
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        button.layer?.add(animation, forKey: "pulse")
    }
}
import SwiftUI
import WebKit

// Toast notification view that appears in the center of the chat
struct ChatToastView: View {
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        if isShowing {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 28))
                        
                        Text(message)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.windowBackgroundColor).opacity(0.98))
                                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.green, lineWidth: 2)
                                    )
                            )
                            .foregroundColor(.primary)
                            .font(.system(size: 16, weight: .medium))
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.1))
                            .blur(radius: 5)
                    )
                    Spacer()
                }
                Spacer()
            }
            .transition(.opacity)
            .zIndex(999) // Ensure it appears above everything else
            .animation(.easeInOut(duration: 0.3), value: isShowing)
            .onAppear {
                // Automatically hide the toast after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        isShowing = false
                    }
                }
            }
        }
    }
}

struct CompactChatView: View {
    @State private var selectedService: AIService
    @State private var isLoading = true
    @StateObject private var preferences = PreferencesManager.shared
    @State private var showToast = false
    
    let services: [AIService]
    let closeAction: () -> Void
    
    // Computed property to get visible services based on preferences
    private var visibleServices: [AIService] {
        return services.filter { service in
            preferences.isModelVisible(service.name)
        }
    }
    
    init(services: [AIService] = aiServices, closeAction: @escaping () -> Void) {
        self.services = services
        self.closeAction = closeAction
        
        // Find first visible service as default
        let firstVisible = services.first { service in
            PreferencesManager.shared.isModelVisible(service.name)
        } ?? services.first!
        
        _selectedService = State(initialValue: firstVisible)
    }
    
    // Initialize with a specific service
    init(initialService: AIService, services: [AIService] = aiServices, closeAction: @escaping () -> Void) {
        self.services = services
        self.closeAction = closeAction
        _selectedService = State(initialValue: initialService)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header with adaptive service selector icons
                HStack(spacing: 0) {
                    // Horizontal icons for service selection - with better spacing
                    HStack(spacing: 2) { // Small consistent spacing between buttons
                        ForEach(visibleServices) { service in
                            AdaptiveServiceIconButton(
                                service: service,
                                isSelected: service.id == selectedService.id,
                                totalVisible: visibleServices.count,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedService = service
                                    }
                                    // When service changes, ensure we refocus the webview after a short delay
                                    ensureWebViewFocus(delay: 0.5)
                                }
                            )
                            .id(service.id) // Ensure ForEach updates properly
                        }
                    }
                    .padding(.horizontal, 6) // Increased horizontal padding
                    
                    Spacer()
                    
                    // Pin button removed - now in title bar
                }
                .padding(.vertical, 8) // Increased vertical padding
                .background(Color(NSColor.windowBackgroundColor))
                
                // Service indicator bar
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(selectedService.color)
                
                // Web view for the selected service with focus handling
                PersistentWebView(service: selectedService, isLoading: $isLoading)
                    .background(KeyboardFocusModifier(onAppear: {
                        // When web view appears, set up a delayed action to focus the view
                        ensureWebViewFocus(delay: 0.5)
                    }))
            }
            
            // Overlay the toast notification on top of everything
            ChatToastView(
                message: "Screenshot copied! Please paste it in your favorite AI",
                isShowing: $showToast
            )
        }
        .frame(width: 400, height: 600)
        .onAppear {
            // Set up periodic focus checks
            setupPeriodicFocusCheck()
            // Ensure focus immediately
            ensureWebViewFocus(delay: 0.2)
            
            // Add observer for screenshot notifications
            NotificationCenter.default.addObserver(
                forName: Notification.Name("ScreenshotTaken"),
                object: nil,
                queue: .main
            ) { [self] _ in
                // Show the toast
                withAnimation {
                    self.showToast = true
                }
            }
        }
        .onDisappear {
            // Remove the observer when the view disappears
            NotificationCenter.default.removeObserver(
                self,
                name: Notification.Name("ScreenshotTaken"),
                object: nil
            )
        }
        // Add observer for model visibility changes
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ModelVisibilityChanged"))) { _ in
            // If the currently selected service is now hidden, switch to the first visible one
            if !preferences.isModelVisible(selectedService.name), let firstVisible = visibleServices.first {
                selectedService = firstVisible
            }
        }
    }
    
    // Function to periodically check and ensure focus is on the webview
    private func setupPeriodicFocusCheck() {
        // Create a timer that checks focus every 1 second
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            guard let window = NSApplication.shared.keyWindow,
                  window.isVisible else {
                return
            }
            
            // Only check and fix focus when the window is key but focus is missing
            if window.isKeyWindow {
                if let firstResponder = window.firstResponder {
                    let className = NSStringFromClass(type(of: firstResponder))
                    // If the first responder is not a WKWebView or KeyboardResponderView,
                    // try to focus the webview - but only if user isn't typing in an input
                    if !className.contains("WKWebView") && !className.contains("KeyboardResponderView") {
                        // Safely check if user is typing before focusing
                        let isTyping = (WebViewCache.shared.value(forKey: "isUserTyping") as? Bool) ?? false
                        if !isTyping {
                            focusWebView()
                        }
                    }
                } else {
                    // If there's no first responder, try to focus the webview
                    focusWebView()
                }
            }
        }
    }
    
    // Simplified function to help focus the web view - just once, no multiple attempts
    private func ensureWebViewFocus(delay: TimeInterval = 0.0) {
        // Just one attempt with minimal or no delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.focusWebView()
        }
    }
    
    // Function to help focus the web view - try to find any WKWebView
    private func focusWebView() {
        guard let window = NSApplication.shared.keyWindow else { return }
        
        // Find any WKWebView in the view hierarchy and make it first responder
        func findAndFocusWebView(in view: NSView) -> Bool {
            // First check if view is a WKWebView (best choice)
            if NSStringFromClass(type(of: view)).contains("WKWebView") {
                window.makeFirstResponder(view)
                return true
            }
            
            // Then check if it's a KeyboardResponderView (second choice)
            if NSStringFromClass(type(of: view)).contains("KeyboardResponderView") {
                window.makeFirstResponder(view)
                return true
            }
            
            // Recursively check subviews
            for subview in view.subviews {
                if findAndFocusWebView(in: subview) {
                    return true
                }
            }
            
            return false
        }
        
        // Start searching from the window's content view
        if let contentView = window.contentView {
            _ = findAndFocusWebView(in: contentView)
        }
    }
    
    // Alternative method to focus the webview using the WebViewCache
    // Only used when direct focus methods fail
    private func alternativeFocusMethod() {
        // Get the webview from the cache
        let webView = WebViewCache.shared.getWebView(for: selectedService)
        
        if let window = webView.window {
            window.makeFirstResponder(webView)
        }
    }
}

// New adaptive service button that resizes based on available space
struct AdaptiveServiceIconButton: View {
    let service: AIService
    let isSelected: Bool
    let totalVisible: Int
    let action: () -> Void
    
    // Calculate adaptive sizing based on number of visible services
    private var buttonWidth: CGFloat {
        // More optimized calculation - adjusts based on total visible services
        // This fills the entire available width with proper spacing
        let containerWidth: CGFloat = 392 // 400 window width - 8 padding
        let spacing: CGFloat = 2 // Small spacing between buttons
        
        let availableWidth = containerWidth - (spacing * CGFloat(totalVisible - 1))
        let calculatedWidth = availableWidth / CGFloat(totalVisible)
        
        // Use min/max to keep reasonable bounds
        return min(max(calculatedWidth, 36), 70)
    }
    
    // Dynamic icon sizing based on available width and number of visible services
    private var iconSize: CGFloat {
        // More visible items = slightly smaller icons
        // Fewer visible items = larger icons
        if totalVisible <= 3 {
            return 24 // Large icons for 1-3 services
        } else if totalVisible <= 6 {
            return 20 // Medium icons for 4-6 services
        } else {
            return 18 // Smaller icons for 7+ services
        }
    }
    
    // Dynamic font sizing to match icon scale
    private var fontSize: CGFloat {
        if totalVisible <= 3 {
            return 12 // Larger font for fewer services
        } else if totalVisible <= 6 {
            return 10 // Medium font
        } else {
            return 9 // Smaller font for many services
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(service.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(isSelected ? service.color : .gray)
                
                Text(service.name)
                    .font(.system(size: fontSize, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundColor(isSelected ? service.color : .gray)
            }
            .frame(width: buttonWidth, height: 40)
            .contentShape(Rectangle()) // Improves tap area to entire frame
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? service.color.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? service.color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(BorderlessButtonStyle()) // More responsive than PlainButtonStyle
    }
}

// Helper view modifier for handling keyboard focus
struct KeyboardFocusModifier: NSViewRepresentable {
    let onAppear: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onAppear()
        }
    }
}

// Preview for SwiftUI Canvas
struct CompactChatView_Previews: PreviewProvider {
    static var previews: some View {
        CompactChatView(closeAction: {})
            .frame(width: 400, height: 600)
            .padding()
            .background(Color.gray.opacity(0.2))
            .previewLayout(.sizeThatFits)
    }
} 
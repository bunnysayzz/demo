import Cocoa
import WebKit
import AVFoundation
import SwiftUI
// Import WebKit with preconcurrency attribute
@preconcurrency import WebKit

// ServiceManagement import removed to prevent open at login

// MARK: - Animated Pin Button
struct AnimatedPinButton: View {
    @Binding var isPinned: Bool
    @State private var isHovered = false
    @State private var isPressed = false
    
    // Animation timing
    private let animation = Animation.interpolatingSpring(
        mass: 0.8,
        stiffness: 250,
        damping: 15,
        initialVelocity: 5
    )
    
    // Animation values
    private let normalScale: CGFloat = 1.0
    private let hoverScale: CGFloat = 1.25
    private let pressedScale: CGFloat = 0.88
    
    // Visual styling
    private let buttonSize: CGFloat = 30
    private let iconSize: CGFloat = 14
    
    var body: some View {
        Button(action: {
            // Immediately update the state to force a view update
            isPressed = true
            
            // Toggle the pinned state with animation
            withAnimation(animation) {
                isPinned.toggle()
            }
            
            // Reset pressed state after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(animation) {
                    isPressed = false
                }
            }
        }) {
            ZStack {
                // Background with subtle scaling and opacity changes
                Circle()
                    .fill(isPinned ? 
                          Color.accentColor.opacity(isHovered ? 0.18 : 0.12) : 
                          (isHovered ? Color.primary.opacity(0.12) : Color.clear))
                    .frame(width: buttonSize, height: buttonSize)
                    .scaleEffect(isPressed ? pressedScale : (isHovered ? hoverScale : normalScale))
                    .animation(animation, value: isHovered)
                
                // Pin icon with smooth transitions
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(isPinned ? .accentColor : .secondary)
                    .rotationEffect(.degrees(isPinned ? 45 : 0))
                    .scaleEffect(isPressed ? pressedScale : (isHovered ? hoverScale : normalScale))
                    .saturation(isPinned ? 1.2 : 1.0)
                    .animation(animation, value: isPinned)
                    .animation(animation, value: isPressed)
            }
            .frame(width: buttonSize + 8, height: buttonSize + 8)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(animation) {
                    isHovered = hovering
                }
            }
            .pressEvents {
                withAnimation(animation) {
                    isPressed = true
                }
            } onRelease: {
                withAnimation(animation) {
                    isPressed = false
                }
            }
        }
        .buttonStyle(BorderlessButtonStyle())
        .help(isPinned ? "Unpin Window" : "Pin Window")
    }
}

// MARK: - Button Press Modifier
struct ButtonPressModifier: ViewModifier {
    @State private var isPressed = false
    let onPress: () -> Void
    let onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isPressed) { newValue in
                if newValue {
                    onPress()
                } else {
                    onRelease()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping (() -> Void), onRelease: @escaping (() -> Void)) -> some View {
        modifier(ButtonPressModifier(onPress: { onPress() }, onRelease: { onRelease() }))
    }
}

class MenuBarManager: NSObject, NSMenuDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var popupWindow: NSWindow?
    private var shortcutManager: KeyboardShortcutManager!
    private var eventMonitor: Any?
    private var statusMenu: NSMenu!
    private var preferencesWindow: NSWindow?
    private var localEventMonitor: Any?
    
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if let iconImage = NSImage(named: "MenuBarIcon") {
                button.image = iconImage
                button.image?.size = NSSize(width: 18, height: 18) // Adjust size to match menu bar
            }
            button.imagePosition = .imageLeft
            
            // Set up the action to handle clicks
            button.target = self
            button.action = #selector(handleStatusItemClick)
            
            // Set up to detect right-clicks
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Create the menu but don't assign it to the status item yet
        statusMenu = createMenu()
        statusMenu.minimumWidth = 220
        statusMenu.delegate = self
        
        // Setup keyboard shortcut manager
        shortcutManager = KeyboardShortcutManager(menuBarManager: self)
        
        // Register for notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenServiceNotification(_:)),
            name: NSNotification.Name("OpenAIService"),
            object: nil
        )
        
        // Register for SelectAIService notifications (used by the Apply button for Gemini API key)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSelectAIServiceNotification(_:)),
            name: NSNotification.Name("SelectAIService"),
            object: nil
        )
        
        // Observe pinned position toggle to optionally reposition while visible
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePinnedPositionChanged),
            name: Notification.Name("PinnedPositionChanged"),
            object: nil
        )
        
        // Setup event monitor to detect clicks outside the window
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.popupWindow else { return }
            
            // Check if the click is outside the window
            if window.isVisible {
                // Don't hide the window if a file picker is active
                if WebViewCache.shared.isFilePickerActive {
                    return
                }
                
                // Don't hide the window if "Always on top" is enabled
                if PreferencesManager.shared.alwaysOnTop {
                    return
                }
                
                let mouseLocation = NSEvent.mouseLocation
                let windowFrame = window.frame
                
                if !NSPointInRect(mouseLocation, windowFrame) {
                    self.closePopupWindow()
                }
            }
        }
    }
    
    deinit {
        // Clean up event monitor
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Remove any observers
        NotificationCenter.default.removeObserver(self)
        
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
    
    @objc func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        
        // Check if it's a right-click
        if event?.type == .rightMouseUp {
            // Show the menu on right-click
            statusItem.menu = statusMenu
            sender.performClick(nil)
            statusItem.menu = nil // Remove the menu after click
        } else {
            // Left-click behavior: toggle the popup window
            if let window = popupWindow, window.isVisible {
                closePopupWindow()
            } else {
                openPopupWindow()
            }
        }
    }
    
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Open main window - adding Command+E keyboard shortcut
        let openItem = NSMenuItem(
            title: "Open Apple AI Pro",
            action: #selector(togglePopupWindow),
            keyEquivalent: "e"  // "e" for Command+E
        )
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add current version information (short+build if available)
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let versionString: String = {
            if let short = shortVersion, let build = buildVersion {
                return short == build ? short : "\(short) (\(build))"
            }
            return shortVersion ?? buildVersion ?? "Unknown"
        }()
        let versionItem = NSMenuItem(
            title: "Version \(versionString)",
            action: nil,
            keyEquivalent: ""
        )
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        
        if menu.items.last?.isSeparatorItem == false {
        menu.addItem(NSMenuItem.separator())
        }
        
        // Quick access to specific AI models
        // Filter the services based on visibility settings
        let visibleServices = aiServices.filter { service in
            PreferencesManager.shared.isModelVisible(service.name)
        }
        
        // Create a menu item for each visible service
        for (index, service) in visibleServices.enumerated() {
            // For Grok, use index 6 if we've added 6 services
            let keyEquivalent = index < 9 ? "\(index + 1)" : "0"
            
            let item = NSMenuItem(
                title: service.name,
                action: #selector(openSpecificService(_:)),
                keyEquivalent: keyEquivalent
            )
            item.target = self
            item.keyEquivalentModifierMask = [NSEvent.ModifierFlags.option, NSEvent.ModifierFlags.command]
            
            // Create a custom view for the menu item with an icon
            let customView = NSHostingView(rootView: 
                HStack {
                    Image(service.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(service.color)
                    Text(service.name)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("⌘⌥\(keyEquivalent)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(width: 180, height: 20)
                .padding(.horizontal, 8)
            )
            
            item.view = customView
            item.representedObject = service
            menu.addItem(item)
        }
        
        // Add preferences and quit
        menu.addItem(NSMenuItem.separator())
        
        let prefsItem = NSMenuItem(
            title: "Preferences",
            action: #selector(showPreferences),
            keyEquivalent: ""  // Removed "," keyboard shortcut
        )
        prefsItem.target = self
        menu.addItem(prefsItem)
        
        // Group separator
        if menu.items.last?.isSeparatorItem == false {
            menu.addItem(NSMenuItem.separator())
        }
        
        // GitHub link
        let githubItem = NSMenuItem(
            title: "GitHub",
            action: #selector(openGitHub),
            keyEquivalent: ""
        )
        githubItem.target = self
        menu.addItem(githubItem)
        
        // Separator between GitHub and More Apps
        if menu.items.last?.isSeparatorItem == false {
            menu.addItem(NSMenuItem.separator())
        }
        
        // More Apps link
        let macAppsItem = NSMenuItem(
            title: "More Apps",
            action: #selector(openMacApps),
            keyEquivalent: ""
        )
        macAppsItem.target = self
        menu.addItem(macAppsItem)
        
        // Group separator before Quit
        if menu.items.last?.isSeparatorItem == false {
            menu.addItem(NSMenuItem.separator())
        }
        
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)
        
        // Bottom spacer to avoid clipping
        let bottomSpacer = NSMenuItem()
        bottomSpacer.view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 8))
        bottomSpacer.isEnabled = false
        menu.addItem(bottomSpacer)
        
        return menu
    }
    
    @objc func togglePopupWindow() {
        if let window = popupWindow, window.isVisible {
            closePopupWindow()
        } else {
            openPopupWindow()
        }
    }
    
    private func closePopupWindow() {
        // Just hide the window rather than closing it
        popupWindow?.orderOut(nil)
    }
    
    @objc func handleOpenServiceNotification(_ notification: Notification) {
        if let serviceName = notification.object as? String,
           let service = aiServices.first(where: { $0.name == serviceName }) {
            openPopupWindowWithService(service)
        }
    }
    
    @objc func handleSelectAIServiceNotification(_ notification: Notification) {
        // Handle service selection by service ID
        if let serviceIdString = notification.object as? String {
            if let service = aiServices.first(where: { $0.id.uuidString == serviceIdString }) {
                openPopupWindowWithService(service)
            }
        }
    }
    
    @objc func openSpecificService(_ sender: NSMenuItem) {
        guard let service = sender.representedObject as? AIService else { return }
        openPopupWindowWithService(service)
    }
    
    @objc func windowDidBecomeKey(_ notification: Notification) {
        // Ensure the web view becomes first responder when the window becomes key
        if let window = notification.object as? NSWindow {
            // Recursively search for WKWebView and make it first responder
            // Use a sequence of timed attempts to ensure views are ready
            makeWebViewFirstResponderWithRetry(window: window)
        }
    }
    
    private func makeWebViewFirstResponderWithRetry(window: NSWindow) {
        // Multiple attempts at different times to handle race conditions
        let delays: [TimeInterval] = [0.1, 0.3, 0.5, 0.8]
        
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.findAndFocusWebView(in: window.contentView)
            }
        }
    }
    
    private func findAndFocusWebView(in view: NSView?) {
        guard let view = view else { return }
        
        // Try to find KeyboardResponderView first (best option)
        if NSStringFromClass(type(of: view)).contains("KeyboardResponderView") {
            DispatchQueue.main.async {
                if let window = view.window {
                    window.makeFirstResponder(view)
                }
            }
            return
        }
        
        // Then try to find WKWebView
        if NSStringFromClass(type(of: view)).contains("WKWebView") {
            DispatchQueue.main.async {
                if let window = view.window {
                    window.makeFirstResponder(view)
                }
            }
            return
        }
        
        // Recursively check subviews
        for subview in view.subviews {
            findAndFocusWebView(in: subview)
        }
    }
    
    private func openPopupWindow() {
        // If window already exists, just show it
        if let window = popupWindow {
            positionAndShowPopupWindow(window)
            return
        }
        
        // Create a new popup window with only titlebar and close button
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        // Configure the window
        window.title = "Apple AI Pro"
        window.isReleasedWhenClosed = false // Important: Don't release window when closed
        
        // Set initial window level based on preference
        window.level = PreferencesManager.shared.alwaysOnTop ? .floating : .normal
        
        // Set collection behavior to ensure it appears on current space
        window.collectionBehavior = [.moveToActiveSpace, .transient]
        
        // Enable keyboard event handling
        window.acceptsMouseMovedEvents = true
        window.isMovable = true
        
        // Critical for keyboard input
        window.initialFirstResponder = nil // Let SwiftUI handle first responder
        window.allowsToolTipsWhenApplicationIsInactive = true
        window.hidesOnDeactivate = false
        
        // Set up keyboard event monitoring for this window to intercept problematic keys
        setupWindowKeyEventMonitoring(window)
        
        // Set the window delegate to handle close button
        window.delegate = self
        
        // Add pin button to title bar
        addPinButtonToTitleBar(window)
        
        // Set the content view to our CompactChatView
        let contentView = CompactChatView(closeAction: { [weak self] in
            self?.closePopupWindow()
        })
        window.contentView = NSHostingView(rootView: contentView)
        
        // Store the window
        popupWindow = window
        
        // Position and show the window
        positionAndShowPopupWindow(window)
        
        // Register for window focus notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
    }
    
    // Add a key event monitor to prevent problematic keys from causing the app to quit
    private func setupWindowKeyEventMonitoring(_ window: NSWindow) {
        // Add a local monitor for key events to prevent app quitting
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, let window = self.popupWindow, event.window == window else {
                return event
            }
            
            // Check for Copilot voice chat activity
            if self.isInCopilotVoiceChat(window) {
                // When in Copilot voice chat, let all keypresses through to the window
                return event
            }
            
            // Check if we have a first responder
            guard let firstResponder = window.firstResponder else {
                // If no first responder, toggle the window off instead of letting the event propagate
                self.closePopupWindow()
                return nil // Consume the event
            }
            
            // Check if the first responder is a text field, KeyboardResponderView, or a WKWebView
            let firstResponderClass = NSStringFromClass(type(of: firstResponder))
            let isInput = firstResponderClass.contains("WKWebView") ||
                          firstResponderClass.contains("KeyboardResponderView") ||
                          firstResponderClass.contains("NSTextField") ||
                          firstResponderClass.contains("NSTextView")
            
            if isInput {
                // Let the input handle all keystrokes
                return event
            } else {
                // For non-input first responders, toggle the window off instead of letting the event propagate
                // This prevents any key from quitting the app
                self.closePopupWindow()
                return nil // Consume the event
            }
        }
    }
    
    // Helper method to check if Copilot voice chat is active
    private func isInCopilotVoiceChat(_ window: NSWindow) -> Bool {
        // Find Copilot webView in the window
        var foundWebView: WKWebView? = nil
        
        // Function to recursively search for WKWebView
        func findWKWebView(in view: NSView) -> WKWebView? {
            // Check if this view is a WKWebView
            if let webView = view as? WKWebView {
                return webView
            }
            
            // Search in subviews
            for subview in view.subviews {
                if let webView = findWKWebView(in: subview) {
                    return webView
                }
            }
            
            return nil
        }
        
        // Find WKWebView in the window's content view
        if let contentView = window.contentView {
            foundWebView = findWKWebView(in: contentView)
        }
        
        // Check if it's a Copilot webview and if voice chat is active
        if let webView = foundWebView,
           let url = webView.url,
           url.host?.contains("copilot.microsoft.com") == true {
            // Check for voice chat UI elements
            let voiceChatScript = """
            (function() {
                return document.querySelectorAll(
                    '[aria-label="Stop voice input"], ' +
                    '.voice-input-container:not(.hidden), ' +
                    '[data-testid="voice-input-button"].active, ' +
                    '.voice-input-active, ' +
                    '.sydney-voice-input'
                ).length > 0;
            })();
            """
            
            var isVoiceChat = false
            let semaphore = DispatchSemaphore(value: 0)
            
            webView.evaluateJavaScript(voiceChatScript) { (result, error) in
                if let isActive = result as? Bool {
                    isVoiceChat = isActive
                }
                semaphore.signal()
            }
            
            // Wait with a short timeout
            _ = semaphore.wait(timeout: .now() + 0.05)
            
            return isVoiceChat
        }
        
        return false
    }
    
    private func openPopupWindowWithService(_ service: AIService) {
        // If window doesn't exist, create it with the specific service
        if popupWindow == nil {
            // Create a new popup window with only titlebar and close button
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            // Configure the window
            window.title = "Apple AI Pro"
            window.isReleasedWhenClosed = false // Important: Don't release window when closed
            
            // Set initial window level based on preference
            window.level = PreferencesManager.shared.alwaysOnTop ? .floating : .normal
            
            // Set collection behavior to ensure it appears on current space
            window.collectionBehavior = [.moveToActiveSpace, .transient]
            
            // Enable keyboard event handling
            window.acceptsMouseMovedEvents = true
            window.isMovable = true
            
            // Critical for keyboard input
            window.initialFirstResponder = nil // Let SwiftUI handle first responder
            window.allowsToolTipsWhenApplicationIsInactive = true
            window.hidesOnDeactivate = false
            
            // Set up keyboard event monitoring
            setupWindowKeyEventMonitoring(window)
            
            // Set the window delegate to handle close button
            window.delegate = self
            
            // Add pin button to title bar
            addPinButtonToTitleBar(window)
            
            // Set the content view to our CompactChatView with the specific service
            let contentView = CompactChatView(
                initialService: service,
                closeAction: { [weak self] in
                    self?.closePopupWindow()
                }
            )
            window.contentView = NSHostingView(rootView: contentView)
            
            // Store the window
            popupWindow = window
            
            // Position and show the window
            positionAndShowPopupWindow(window)
            
            // Register for window focus notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidBecomeKey),
                name: NSWindow.didBecomeKeyNotification,
                object: window
            )
            return
        }
        
        // If window exists, update the selected service
        if let window = popupWindow {
            // Create a new CompactChatView with the selected service
            let contentView = CompactChatView(
                initialService: service,
                closeAction: { [weak self] in
                    self?.closePopupWindow()
                }
            )
            window.contentView = NSHostingView(rootView: contentView)
            
            // Position and show the window
            positionAndShowPopupWindow(window)
        }
    }
    
    private func positionAndShowPopupWindow(_ window: NSWindow) {
        // Ensure the window appears on the active space
        window.collectionBehavior = [.moveToActiveSpace, .transient]
        
        // Set window level based on alwaysOnTop preference
        window.level = PreferencesManager.shared.alwaysOnTop ? .floating : .normal
        
        // If pinned position mode is enabled and we have a saved frame, use it
        if PreferencesManager.shared.pinnedPositionEnabled, let pinned = PreferencesManager.shared.getPinnedFrame() {
            let targetFrame = NSRect(x: pinned.origin.x, y: pinned.origin.y, width: pinned.size.width, height: pinned.size.height)
            if isFrameOnAnyScreen(targetFrame) {
                window.setFrame(targetFrame, display: false)
            } else {
                // Fallback to default status item placement if saved frame is off-screen
                positionWindowUnderStatusItem(window)
            }
        } else {
            // Default behavior: position the window below the status item
            positionWindowUnderStatusItem(window)
        }
        
        // Ensure window is properly configured for keyboard input
        window.makeKeyAndOrderFront(nil)
        window.isMovableByWindowBackground = false
        window.acceptsMouseMovedEvents = true
        
        // Make the window active and bring app to foreground
        NSApp.activate(ignoringOtherApps: true)
        
        // Attempt to set focus to the webview with multiple timed attempts
        makeWebViewFirstResponderWithRetry(window: window)
        
        // Setup window level observer to update when alwaysOnTop changes
        setupWindowLevelObserver(for: window)
    }
    
    private func positionWindowUnderStatusItem(_ window: NSWindow) {
        if let button = statusItem.button {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = button.window?.convertToScreen(buttonRect)
            
            if let screenRect = screenRect {
                let windowSize = window.frame.size
                let x = screenRect.midX - windowSize.width / 2
                let y = screenRect.minY - windowSize.height
                
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
    }
    
    private func isFrameOnAnyScreen(_ frame: NSRect) -> Bool {
        for screen in NSScreen.screens {
            if screen.visibleFrame.intersects(frame) {
                return true
            }
        }
        return false
    }
    
    // Add observer to update window level when alwaysOnTop preference changes
    private func setupWindowLevelObserver(for window: NSWindow) {
        // Remove existing observer if any
        NotificationCenter.default.removeObserver(self, name: Notification.Name("AlwaysOnTopChanged"), object: nil)
        
        // Add observer for AlwaysOnTopChanged notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateWindowLevel),
            name: Notification.Name("AlwaysOnTopChanged"),
            object: nil
        )
        
        // Immediately update the window level to match current preference
        DispatchQueue.main.async { [weak self] in
            self?.updateWindowLevel()
        }
    }
    
    @objc private func updateWindowLevel() {
        guard let window = popupWindow else { return }
        
        // Update window level based on preference with animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().level = PreferencesManager.shared.alwaysOnTop ? .floating : .normal
        }, completionHandler: {
            // Force the window level update to take effect immediately after animation
            DispatchQueue.main.async {
                window.level = PreferencesManager.shared.alwaysOnTop ? .floating : .normal
                
                // Force window to remain active if always on top
                if PreferencesManager.shared.alwaysOnTop {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        })
    }
    
    @objc func showPreferences() {
        // If window already exists, just show it
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create a new window with enhanced styling
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // Important: Set this to false to prevent the window from being deallocated when closed
        window.isReleasedWhenClosed = false
        
        window.title = "Apple AI Preferences"
        window.contentView = NSHostingView(rootView: EnhancedPreferencesView())
        window.center()
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        // Apply theme-aware styling
        if let appearance = NSAppearance(named: ThemeManager.shared.effectiveAppearance) {
            window.appearance = appearance
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Set the delegate to self to track window close
        window.delegate = self
        
        // Store the window
        preferencesWindow = window
    }
    
    @objc func openGitHub() {
        // Open GitHub URL
        if let url = URL(string: "https://github.com/bunnysayzz/AppleAI.git") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func openMacApps() {
        if let url = URL(string: "https://macbunny.co") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - NSMenuDelegate
    
    func menuDidClose(_ menu: NSMenu) {
        // Ensure the menu is removed after it's closed
        statusItem.menu = nil
    }
    
    // Add a new method to add the pin button to the title bar
    private func addPinButtonToTitleBar(_ window: NSWindow) {
        // Create a state to track pin state (always on top)
        let isPinned = Binding<Bool>(
            get: { PreferencesManager.shared.alwaysOnTop },
            set: { newValue in
                PreferencesManager.shared.setAlwaysOnTop(newValue)
                window.level = newValue ? .floating : .normal
                if newValue {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        )
        
        // Create a state to track position pin state
        let isPositionPinned = Binding<Bool>(
            get: { PreferencesManager.shared.pinnedPositionEnabled },
            set: { newValue in
                PreferencesManager.shared.pinnedPositionEnabled = newValue
                if newValue {
                    PreferencesManager.shared.savePinnedFrame(window.frame)
                }
            }
        )
        
        // Create a SwiftUI hosting controller for the title bar buttons
        let hostingController = NSHostingController(rootView: 
            HStack(spacing: 4) {
                // Screenshot button
                Button(action: { [self] in
                    self.takeScreenshot(window)
                }) {
                    Image(systemName: "camera")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Take Screenshot")
                
                // Position pin toggle
                Button(action: {
                    isPositionPinned.wrappedValue.toggle()
                }) {
                    Image(systemName: isPositionPinned.wrappedValue ? "mappin.circle.fill" : "mappin.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isPositionPinned.wrappedValue ? .accentColor : .secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
                .help(isPositionPinned.wrappedValue ? "Unpin Position" : "Pin Position")
                
                // Animated pin button (always on top)
                AnimatedPinButton(isPinned: isPinned)
            }
            .padding(.trailing, 8)
        )
        
        // Configure the hosting view
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 110, height: 30)
        
        // Create a title bar accessory view controller
        let accessoryViewController = NSTitlebarAccessoryViewController()
        accessoryViewController.view = hostingController.view
        accessoryViewController.layoutAttribute = .trailing
        
        // Add the accessory view controller to the window
        window.addTitlebarAccessoryViewController(accessoryViewController)
    }
    
    // MARK: - NSWindowDelegate
    
    @objc func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // Check if this is the preferences window
        if window == preferencesWindow {
            // Don't set to nil, just hide the window
            window.orderOut(nil)
            print("Preferences window hidden but retained")
            
            // Instead of allowing the normal close behavior, we'll prevent it
            DispatchQueue.main.async {
                // This is important: we're not allowing the window to close normally
                // It will just be hidden, not released or deallocated
                window.orderOut(nil) // Hide the window instead of trying to set isVisible
            }
        }
    }
    
    // Return false to prevent normal window closing behavior for preferences
    @objc func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Handle each window type differently
        if sender == popupWindow {
            // For the main popup window, just hide it
            closePopupWindow()
            return false // Prevent standard close behavior
        } else if sender == preferencesWindow {
            // For the preferences window, hide it but allow the close action
            preferencesWindow?.orderOut(nil)
            return false // Prevent standard close behavior but still hide
        }
        
        // Allow normal closing for any other windows
        return true
    }
    
    // Prevent window minimization
    func windowShouldMiniaturize(_ sender: NSWindow) -> Bool {
        // Always prevent minimization of our popup window
        if sender == popupWindow {
            return false
        }
        return true // Allow minimization for other windows
    }
    
    // Prevent window zoom (maximize)
    @objc func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        // Always prevent zoom for our popup window
        if window == popupWindow {
            return false
        }
        return true // Allow zoom for other windows
    }
    
    func windowDidMove(_ notification: Notification) {
        guard let movedWindow = notification.object as? NSWindow, movedWindow == popupWindow else { return }
        if PreferencesManager.shared.pinnedPositionEnabled, let window = popupWindow {
            PreferencesManager.shared.savePinnedFrame(window.frame)
        }
    }
    
    func windowDidEndLiveResize(_ notification: Notification) {
        guard let resizedWindow = notification.object as? NSWindow, resizedWindow == popupWindow else { return }
        if PreferencesManager.shared.pinnedPositionEnabled, let window = popupWindow {
            PreferencesManager.shared.savePinnedFrame(window.frame)
        }
    }
    
    @objc private func handlePinnedPositionChanged() {
        guard let window = popupWindow, window.isVisible else { return }
        positionAndShowPopupWindow(window)
    }
    
    // Add the method to handle "Check for Updates" menu item action
    
    
    // Helper method to take a screenshot
    private func takeScreenshot(_ window: NSWindow) {
        // Temporarily hide the window to avoid it appearing in the screenshot
        let wasVisible = window.isVisible
        window.orderOut(nil)
        
        // Small delay to ensure window is hidden
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Use system screenshot UI
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-i", "-c"] // Interactive mode, copy to clipboard
            task.launch()
            
            // Wait for screenshot to complete
            task.waitUntilExit()
            
            // Notify listeners that a screenshot was taken (to show toast)
            NotificationCenter.default.post(name: Notification.Name("ScreenshotTaken"), object: nil)
            
            // Make window visible again if it was visible before
            if wasVisible {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    // Public: Trigger interactive area screenshot, copying to clipboard, and ensure window is shown
    func triggerAreaScreenshotAndShowWindow() {
        // If we already have a popup window, use it; else open one and then run screenshot
        if let window = popupWindow {
            takeScreenshot(window)
            // After capture completes, ensure the window is visible
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if !(window.isVisible) {
                    self.positionAndShowPopupWindow(window)
                }
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            // Open window first, then run screenshot
            openPopupWindow()
            if let window = popupWindow {
                // Delay slightly to ensure window is constructed before hiding
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.takeScreenshot(window)
                }
            }
        }
    }
} 
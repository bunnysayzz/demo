import SwiftUI
import AppKit
@_exported import WebKit
import UserNotifications
// import Sparkle

@main
struct AppleAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Initialize theme manager early
        _ = ThemeManager.shared
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            // Add custom menu commands
            CommandGroup(replacing: .appSettings) {
                Button("Preferences...") {
                    appDelegate.showPreferences()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

// App delegate to handle application lifecycle
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    var menuBarManager: MenuBarManager!
    private var microphoneMonitorTimer: Timer?
    private var keyEventMonitor: Any?
    private var flagsEventMonitor: Any?
    var preferencesWindow: NSWindow?
    var mainWindow: NSWindow?
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to accessory (menu bar app)
        NSApp.setActivationPolicy(.accessory)
        
        // Create and setup the menu bar manager
        menuBarManager = MenuBarManager()
        menuBarManager.setup()
        
        // Setup application main menu with keyboard shortcut support
        Task { @MainActor in
            setupMainMenu()
        }
        
        // MAXIMUM PROTECTION: Install truly global keyboard monitors
        setupApplicationWideKeyboardBlocker()
        
        // Also install our regular keyboard handlers for when in text fields
        setupKeyboardShortcuts()
        
        // Prevent app termination by adding a persistent window
        createPersistentWindow()
        
        // Register for termination notification to manually handle app termination
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
        
        // Ensure microphone is stopped at app startup
        stopMicrophoneUsage()
        
        // Start a periodic microphone monitor to prevent the microphone
        // from staying active when it shouldn't be
        startMicrophoneMonitor()
        
        // Setup notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions if not already granted
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("🔔 Notification permission granted")
            } else if let error = error {
                print("❌ Error requesting notification permission: \(error.localizedDescription)")
            }
        }
        
        
    }
    
    @objc func showPreferences() {
        if preferencesWindow == nil {
            let contentView = EnhancedPreferencesView()
                .frame(width: 680, height: 520)
            
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            preferencesWindow?.title = "Apple AI Preferences"
            preferencesWindow?.center()
            preferencesWindow?.contentView = NSHostingView(rootView: contentView)
            preferencesWindow?.isReleasedWhenClosed = false
            preferencesWindow?.titlebarAppearsTransparent = true
            preferencesWindow?.titleVisibility = .hidden
            
            // Apply theme-aware styling
            if let appearance = NSAppearance(named: ThemeManager.shared.effectiveAppearance) {
                preferencesWindow?.appearance = appearance
            }
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // FORTRESS MODE: This aggressively blocks ALL keyboard events system-wide
    // except for Command+E. Nothing else gets through.
    private func setupApplicationWideKeyboardBlocker() {
        // Remove any existing monitors
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = flagsEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        print("Installing FORTRESS MODE keyboard protection")
        
        // LEVEL 1: Global monitor that catches ALL key events
        keyEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            // Global monitor can only observe events, not block them
            // But we'll use it for logging suspicious activity
            if let self = self {
                // Log any key press when we're not expecting it
                print("GLOBAL: Key event detected: \(event.keyCode) [\(event.charactersIgnoringModifiers ?? "")]")
            }
        }
        
        // LEVEL 2: Local monitor that catches ALL key down events
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            print("FORTRESS: Intercepted key \(event.keyCode) [\(event.charactersIgnoringModifiers ?? "")]")
            
            // SPECIAL CASE 0: Block ESC key (0x35) in all contexts to prevent quitting
            // Only block Enter key (0x24) when NOT in a text field
            if event.keyCode == 0x35 || (event.keyCode == 0x24 && !self.isInTextInputField(event.window?.firstResponder)) {
                print("FORTRESS: Blocking ESC/Enter key to prevent app quit")
                return nil
            }
            
            // SPECIAL CASE 1: ALWAYS allow Command+E to trigger our toggle
            if event.modifierFlags.contains(.command) && 
               event.keyCode == 0x0E && 
               event.charactersIgnoringModifiers == "e" {
                print("FORTRESS: Allowing Command+E shortcut")
                return event
            }
            
            // SPECIAL CASE 2: Allow Command+Q but ONLY if it comes from the menu
            if event.modifierFlags.contains(.command) && 
               event.keyCode == 0x0C && 
               event.charactersIgnoringModifiers == "q" {
                
                // Only allow if the first responder is actually an NSMenuItem
                if let firstResponder = NSApp.keyWindow?.firstResponder {
                    let responderClass = String(describing: type(of: firstResponder))
                    if responderClass.contains("NSMenu") || responderClass.contains("NSMenuItem") {
                        print("FORTRESS: Allowing Command+Q from menu item")
                        return event
                    }
                }
                
                print("FORTRESS: Blocking Command+Q not from menu")
                return nil
            }
            
            // SPECIAL CASE 3: Allow key events ONLY when we're in a known text input field
            if let window = event.window, window.isKeyWindow,
               let firstResponder = window.firstResponder {
                
                let responderClass = String(describing: type(of: firstResponder))
                
                // Check for our special KeyboardResponderView or its descendants
                let isInKeyboardView = responderClass.contains("KeyboardResponderView") ||
                                      self.isDescendantOfKeyboardResponderView(firstResponder)
                
                // Very strict check for text field context
                let isTextInputField = 
                    (responderClass.contains("NSTextInputContext") || 
                     responderClass.contains("NSTextView") ||
                     responderClass.contains("WKContentView") ||
                     responderClass.contains("TextInputHost") ||
                     responderClass.contains("NSTextField") ||
                     responderClass.contains("UITextView")) || 
                    // Verify we're truly in a web view input context by checking parent chain
                    self.isInsideWebViewEditingContext(firstResponder) ||
                    // Our KeyboardResponderView handles its own input checking
                    isInKeyboardView
                
                if isTextInputField {
                    // Inside text field, allow normal typing
                    if event.modifierFlags.contains(.command) {
                        // But only allow standard editing shortcuts
                        let standardShortcuts: [UInt16] = [
                            UInt16(0x00), // A - Select All
                            UInt16(0x08), // C - Copy
                            UInt16(0x09), // V - Paste
                            UInt16(0x07), // X - Cut
                            UInt16(0x0C), // Z - Undo
                            UInt16(0x0D)  // Y - Redo
                        ]
                        
                        if standardShortcuts.contains(event.keyCode) {
                            print("FORTRESS: Allowing standard editing shortcut in text field")
                            return event
                        } else {
                            print("FORTRESS: Blocking non-standard shortcut in text field: \(event.keyCode)")
                            return nil
                        }
                    } else {
                        // Block ESC key in all contexts, but allow Enter key in text fields for submission
                        if event.keyCode == 0x35 {
                            print("FORTRESS: Blocking ESC key in text field")
                            return nil
                        }
                        
                        // Allow normal typing in verified text fields
                        print("FORTRESS: Allowing normal typing in text field")
                        return event
                    }
                }
            }
            
            // EXTREME FORTRESS: Block absolutely ALL other key events in all contexts
            // This is the ultimate protection against unexpected quits
            print("FORTRESS: Blocking key event \(event.keyCode) completely")
            return nil
        }
        
        // LEVEL 3: Also install protection for flags changed events (modifier keys)
        flagsEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            // Allow all modifier key events as they don't trigger quits directly
            return event
        }
    }
    
    // Helper to check if a responder is or is descended from KeyboardResponderView
    private func isDescendantOfKeyboardResponderView(_ responder: NSResponder) -> Bool {
        let responderClass = String(describing: type(of: responder))
        if responderClass.contains("KeyboardResponderView") {
            return true
        }
        
        // Check up the responder chain
        var current = responder.nextResponder
        var depth = 0
        while current != nil && depth < 5 {
            let currentClass = String(describing: type(of: current!))
            if currentClass.contains("KeyboardResponderView") {
                return true
            }
            current = current!.nextResponder
            depth += 1
        }
        
        return false
    }
    
    // Helper method to deeply verify we're in a true web view editing context
    private func isInsideWebViewEditingContext(_ responder: NSResponder) -> Bool {
        // First check directly
        let responderClass = String(describing: type(of: responder))
        if responderClass.contains("WKContentView") || 
           responderClass.contains("WKWebView") {
            return true
        }
        
        // Recursively check responder chain up to 5 levels deep
        var currentResponder = responder.nextResponder
        var depth = 0
        
        while currentResponder != nil && depth < 5 {
            let currentClass = String(describing: type(of: currentResponder!))
            
            if currentClass.contains("WKContentView") || 
               currentClass.contains("WKWebView") || 
               currentClass.contains("AIWebView") ||
               currentClass.contains("KeyboardResponderView") {
                return true
            }
            
            currentResponder = currentResponder!.nextResponder
            depth += 1
        }
        
        // Not in a web view context
        return false
    }
    
    // Stop any microphone usage to ensure privacy
    private func stopMicrophoneUsage() {
        // Use WebViewCache to stop all audio resources
        let webViewCache = WebViewCache.shared
        DispatchQueue.main.async {
            webViewCache.stopAllMicrophoneUse()
        }
    }
    
    // Start a periodic monitor to check for and stop microphone usage when inactive
    private func startMicrophoneMonitor() {
        // Cancel any existing timer
        microphoneMonitorTimer?.invalidate()
        
        // Create a new timer that checks microphone status every 3 seconds
        microphoneMonitorTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkAndStopInactiveMicrophone()
        }
    }
    
    // Check if microphone is active but should be inactive, and stop it if needed
    private func checkAndStopInactiveMicrophone() {
        // Access WebViewCache instance
        let webViewCache = WebViewCache.shared
        
        // Instead of accessing private webViews dictionary, use a shared approach
        // to stop all microphone usage first
        webViewCache.stopAllMicrophoneUse()
        
        // Then perform a scheduled check to make sure all audio is actually stopped
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Run JavaScript in the current web view to check status
            if let currentWebView = self.getCurrentActiveWebView() {
                currentWebView.evaluateJavaScript("""
                (function() {
                    // Check if there are any active audio tracks in this page
                    let hasActiveAudio = false;
                    
                    // Check all active audio streams
                    if (window.activeAudioStreams && window.activeAudioStreams.length > 0) {
                        for (const stream of window.activeAudioStreams) {
                            if (stream && typeof stream.getAudioTracks === 'function') {
                                const audioTracks = stream.getAudioTracks();
                                if (audioTracks.some(track => track.readyState === 'live')) {
                                    hasActiveAudio = true;
                                }
                            }
                        }
                    }
                    
                    // If we still have active audio, stop it forcefully
                    if (hasActiveAudio) {
                        // Force stop all audio tracks
                        console.log('Force stopping audio tracks');
                        if (window.activeAudioStreams) {
                            window.activeAudioStreams.forEach(stream => {
                                if (stream && typeof stream.getTracks === 'function') {
                                    stream.getTracks().forEach(track => {
                                        if (track.kind === 'audio') {
                                            track.stop();
                                            track.enabled = false;
                                        }
                                    });
                                }
                            });
                            
                            // Clear active streams array
                            window.activeAudioStreams = [];
                        }
                    }
                    
                    return hasActiveAudio;
                })();
                """) { (result, error) in
                    if let error = error {
                        print("Error checking audio status: \(error)")
                    } else if let hasActiveAudio = result as? Bool, hasActiveAudio {
                        print("Detected active audio and stopped it forcefully")
                    }
                }
            }
        }
    }
    
    // Helper to get the current active web view
    private func getCurrentActiveWebView() -> WKWebView? {
        // Find the main window
        guard let mainWindow = NSApp.windows.first(where: { $0.title == "Apple AI Pro" }) else {
            return nil
        }
        
        // Try to find the WKWebView within the window hierarchy
        func findWebView(in view: NSView?) -> WKWebView? {
            guard let view = view else { return nil }
            
            // Check if this view is a WKWebView
            if let webView = view as? WKWebView {
                return webView
            }
            
            // Otherwise, recursively search in subviews
            for subview in view.subviews {
                if let webView = findWebView(in: subview) {
                    return webView
                }
            }
            
            return nil
        }
        
        return findWebView(in: mainWindow.contentView)
    }
    
    // This is critical - it prevents the app from terminating when all windows are closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // Add a hidden persistent window to prevent app termination
    private func createPersistentWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        window.orderOut(nil)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              willPresent notification: UNNotification, 
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notifications even when app is in foreground
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        // No update actions anymore
        completionHandler()
    }
    
    @objc func appWillTerminate() {
        // Perform cleanup if needed
        print("App is terminating")
        
        // Invalidate the microphone monitor timer
        microphoneMonitorTimer?.invalidate()
        
        // Stop microphone usage when app is terminating
        stopMicrophoneUsage()
    }
    
    // This method is called when the user attempts to quit your app
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Invalidate the microphone monitor timer
        microphoneMonitorTimer?.invalidate()
        
        // Stop microphone usage before terminating
        stopMicrophoneUsage()
        
        // Allow termination
        return .terminateNow
    }
    
    // Handle app entering background
    func applicationDidResignActive(_ notification: Notification) {
        // Stop microphone when app goes into background
        stopMicrophoneUsage()
    }
    
    // Handle when app is hidden
    func applicationWillHide(_ notification: Notification) {
        // Stop microphone when app is hidden
        stopMicrophoneUsage()
    }
    
    private func setupKeyboardShortcuts() {
        // SUPER-STRICT MODE: Block ALL key events unless explicitly allowed
        // This prevents any key from quitting the app unexpectedly
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Handle the event
            guard let self = self else {
                return event
            }
            
            // Allow typing in text fields
            if let responder = NSApp.keyWindow?.firstResponder, responder is NSTextView {
                return event
            }
            
            // Allow normal operation in dialog boxes and sheets
            if NSApp.modalWindow != nil {
                return event
            }
            
            // Default to letting the event pass through
            return event
        }
    }
    
    @MainActor
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        // Add About item
        let aboutMenuItem = NSMenuItem(
            title: "About AppleAI",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(aboutMenuItem)
        
        // Updates removed
        
        // Add Preferences item
        let preferencesMenuItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(AppDelegate.showPreferences),
            keyEquivalent: ","
        )
        preferencesMenuItem.target = self
        appMenu.addItem(preferencesMenuItem)
        
        // Add separator
        appMenu.addItem(NSMenuItem.separator())
        
        // Add standard service menu
        let servicesMenuItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        appMenu.addItem(servicesMenuItem)
        let servicesMenu = NSMenu()
        servicesMenuItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        
        // Add separator
        appMenu.addItem(NSMenuItem.separator())
        
        // Add Hide, Hide Others, Show All items
        appMenu.addItem(NSMenuItem(title: "Hide AppleAI", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        
        let hideOthersMenuItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersMenuItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersMenuItem)
        
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        
        // Add separator
        appMenu.addItem(NSMenuItem.separator())
        
        // Add Quit item
        appMenu.addItem(NSMenuItem(title: "Quit AppleAI", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        // Set the main menu
        NSApp.mainMenu = mainMenu
    }
    
    deinit {
        // Clean up event monitors
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = flagsEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    // Add a helper method to check if we're in a text input field where Enter should work
    private func isInTextInputField(_ responder: NSResponder?) -> Bool {
        guard let responder = responder else { return false }
        
        let responderClass = String(describing: type(of: responder))
        
        // Check if this is a text input context where Enter should be allowed
        let isTextField = responderClass.contains("NSTextInputContext") || 
                         responderClass.contains("NSTextView") ||
                         responderClass.contains("WKContentView") ||
                         responderClass.contains("TextInputHost") ||
                         responderClass.contains("NSTextField") ||
                         responderClass.contains("UITextView") ||
                         responderClass.contains("KeyboardResponderView")
        
        if isTextField {
            return true
        }
        
        // Also check if we're in a web view context
        if isInsideWebViewEditingContext(responder) {
            return true
        }
        
        return false
    }
    

} 
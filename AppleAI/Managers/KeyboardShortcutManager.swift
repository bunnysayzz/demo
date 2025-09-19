import AppKit
import Carbon.HIToolbox

class KeyboardShortcutManager {
    private var menuBarManager: MenuBarManager
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var hotKeyID = EventHotKeyID()
    private let preferences = PreferencesManager.shared
    
    // Add a second hotkey for screenshot (Option + D)
    private var screenshotHotKeyRef: EventHotKeyRef?
    private var screenshotHotKeyID = EventHotKeyID()
    
    // Static C-callback kept alive for the lifetime of the app
    private static let hotKeyEventHandler: EventHandlerUPP = { (_, event, userData) -> OSStatus in
        guard let userData = userData else { return OSStatus(eventNotHandledErr) }
        let manager = Unmanaged<KeyboardShortcutManager>.fromOpaque(userData).takeUnretainedValue()
        
        var hkID = EventHotKeyID()
        let error = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hkID
        )
        
        if error == noErr {
            // Primary toggle hotkey (user-configurable, default Cmd+E)
            if hkID.signature == manager.hotKeyID.signature && hkID.id == manager.hotKeyID.id {
                DispatchQueue.main.async {
                    manager.menuBarManager.togglePopupWindow()
                }
                return noErr
            }
            // Screenshot hotkey (Option + D)
            if hkID.signature == manager.screenshotHotKeyID.signature && hkID.id == manager.screenshotHotKeyID.id {
                DispatchQueue.main.async {
                    manager.triggerAreaScreenshot()
                }
                return noErr
            }
        }
        return OSStatus(eventNotHandledErr)
    }
    
    init(menuBarManager: MenuBarManager) {
        self.menuBarManager = menuBarManager
        
        // Setup hotkey IDs with custom signatures
        hotKeyID.signature = fourCharCode("AIAI")
        hotKeyID.id = 1
        
        screenshotHotKeyID.signature = fourCharCode("SHOT")
        screenshotHotKeyID.id = 2
        
        // Observe hotkey change notifications to re-register
        NotificationCenter.default.addObserver(self, selector: #selector(hotkeyChanged), name: Notification.Name("HotkeyChanged"), object: nil)
        
        setupShortcuts()
    }
    
    deinit {
        unregisterGlobalHotKey()
        if let handlerRef = handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func hotkeyChanged() {
        registerGlobalHotKey()
    }
    
    private func setupShortcuts() {
        // Register the global hotkey using stored preferences (defaults to ⌘E)
        registerGlobalHotKey()
        
        // Register the screenshot hotkey (⌥D)
        registerScreenshotHotKey()
    }
    
    private func installHandlerIfNeeded() {
        if handlerRef == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                        eventKind: OSType(kEventHotKeyPressed))
            let err = InstallEventHandler(
                GetApplicationEventTarget(),
                KeyboardShortcutManager.hotKeyEventHandler,
                1,
                &eventType,
                Unmanaged.passUnretained(self).toOpaque(),
                &handlerRef
            )
            if err != noErr {
                print("Error installing event handler: \(err)")
            }
        }
    }
    
    private func registerGlobalHotKey() {
        // Unregister existing hotkey
        if let hotKeyRef = hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        
        // Ensure handler is installed
        installHandlerIfNeeded()
        
        // Read user-configured keyCode and modifiers
        let config = preferences.getHotKeyConfig()
        let keyCode = config.keyCode
        let modifiers = config.modifiers
        
        // Register the hotkey
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            print("Error registering hotkey: \(status)")
        }
    }
    
    private func registerScreenshotHotKey() {
        // Unregister existing screenshot hotkey
        if let ref = screenshotHotKeyRef { UnregisterEventHotKey(ref); screenshotHotKeyRef = nil }
        
        // Ensure handler is installed
        installHandlerIfNeeded()
        
        // Register Option + D
        let keyCode = UInt32(kVK_ANSI_D)
        let modifiers = UInt32(optionKey)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            screenshotHotKeyID,
            GetApplicationEventTarget(),
            0,
            &screenshotHotKeyRef
        )
        if status != noErr {
            print("Error registering screenshot hotkey: \(status)")
        }
    }
    
    private func unregisterGlobalHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let ref = screenshotHotKeyRef {
            UnregisterEventHotKey(ref)
            screenshotHotKeyRef = nil
        }
    }
    
    // Helper method to directly toggle the popup window
    @objc func togglePopupWindow() {
        menuBarManager.togglePopupWindow()
    }
    
    // Trigger the same screenshot flow as the camera button, then open window
    private func triggerAreaScreenshot() {
        // Call into MenuBarManager safe API
        menuBarManager.triggerAreaScreenshotAndShowWindow()
    }
    
    private func runSystemScreenshot(_ window: NSWindow?) {
        // Hide window if provided
        let wasVisible = window?.isVisible ?? false
        window?.orderOut(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-i", "-c"] // Interactive, copy to clipboard
            task.launch()
            task.waitUntilExit()
            
            // Notify UI toast listeners
            NotificationCenter.default.post(name: Notification.Name("ScreenshotTaken"), object: nil)
            
            // Restore window if it was visible, otherwise show the window now
            if wasVisible {
                window?.makeKeyAndOrderFront(nil)
            } else {
                self.menuBarManager.togglePopupWindow()
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    // Convert a four character string to a FourCharCode
    private func fourCharCode(_ string: String) -> FourCharCode {
        assert(string.count == 4, "String length must be exactly 4")
        var result: FourCharCode = 0
        for char in string.utf16 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }
}
import SwiftUI
import Carbon.HIToolbox

@available(macOS 11.0, *)
class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    // Open at login functionality has been removed
    
    @Published var alwaysOnTop: Bool {
        didSet {
            UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop")
            // Post notification for window level changes
            NotificationCenter.default.post(name: Notification.Name("AlwaysOnTopChanged"), object: nil)
        }
    }
    
    // New dictionary to store visibility status for each AI model
    @Published var modelVisibility: [String: Bool] = [:] {
        didSet {
            // Save to UserDefaults whenever it changes
            UserDefaults.standard.set(modelVisibility, forKey: "modelVisibility")
            // Post notification for model visibility changes
            NotificationCenter.default.post(name: Notification.Name("ModelVisibilityChanged"), object: nil)
        }
    }
    
    // When enabled, the popup window will open at a saved pinned screen position
    @Published var pinnedPositionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(pinnedPositionEnabled, forKey: "pinnedPositionEnabled")
            NotificationCenter.default.post(name: Notification.Name("PinnedPositionChanged"), object: nil)
        }
    }
    
    // User-configurable global hotkey (defaults to ⌘E)
    // Stored in UserDefaults as integers
    private(set) var hotkeyKeyCode: UInt32
    private(set) var hotkeyModifiers: UInt32
    
    private let defaultsHotkeyKeyCode: UInt32 = UInt32(kVK_ANSI_E)
    private let defaultsHotkeyModifiers: UInt32 = UInt32(cmdKey)
    
    private init() {
        self.alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
        
        // Load hotkey (or defaults) FIRST to avoid using self before full init
        let storedKey = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
        let storedMods = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
        if storedKey != 0 || storedMods != 0 {
            self.hotkeyKeyCode = UInt32(storedKey)
            self.hotkeyModifiers = UInt32(storedMods)
        } else {
            self.hotkeyKeyCode = defaultsHotkeyKeyCode
            self.hotkeyModifiers = defaultsHotkeyModifiers
        }
        
        // Load model visibility settings, defaulting to all visible
        if let savedVisibility = UserDefaults.standard.dictionary(forKey: "modelVisibility") as? [String: Bool] {
            self.modelVisibility = savedVisibility
            
            // Ensure any new models not in saved settings are added with default visibility
            var updatedVisibility = savedVisibility
            var madeChanges = false
            
            for service in aiServices {
                if savedVisibility[service.name] == nil {
                    // Default new models to visible unless they're in the default hidden list
                    let defaultHiddenModels = ["Claude", "Grok", "Mistral", "Pi"]
                    // Make askAppleAI visible by default
                    if service.name == "askAppleAI" {
                        updatedVisibility[service.name] = true
                    } else {
                        updatedVisibility[service.name] = !defaultHiddenModels.contains(service.name)
                    }
                    madeChanges = true
                }
            }
            
            if madeChanges {
                UserDefaults.standard.set(updatedVisibility, forKey: "modelVisibility")
                modelVisibility = updatedVisibility
            }
        } else {
            // Initialize with defaults inline to avoid calling instance methods before full init
            var visibility: [String: Bool] = [:]
            for service in aiServices {
                if service.name == "Mistral" || service.name == "Gemini" || service.name == "Pi" {
                    visibility[service.name] = false
                } else {
                    visibility[service.name] = true
                }
            }
            modelVisibility = visibility
        }
        
        // Load pinned position enabled state
        self.pinnedPositionEnabled = UserDefaults.standard.bool(forKey: "pinnedPositionEnabled")
    }
    
    // Initialize model visibility settings with all standard AI models visible
    // but the new ones (Mistral, Gemini, Pi) hidden by default
    private func initializeModelVisibility() {
        var visibility: [String: Bool] = [:]
        for service in aiServices {
            // Set new models to be hidden by default
            if service.name == "Mistral" || service.name == "Gemini" || service.name == "Pi" {
                visibility[service.name] = false
            } else {
                visibility[service.name] = true
            }
        }
        modelVisibility = visibility
    }
    
    // MARK: - Model Visibility
    
    // Get if a model is visible
    func isModelVisible(_ modelName: String) -> Bool {
        return modelVisibility[modelName] ?? true
    }
    
    // Toggle visibility for a specific model
    func toggleModelVisibility(for modelName: String) {
        var updatedVisibility = modelVisibility
        updatedVisibility[modelName] = !(modelVisibility[modelName] ?? true)
        modelVisibility = updatedVisibility
    }
    
    // Set visibility directly for a model
    func setModelVisibility(_ isVisible: Bool, for modelName: String) {
        var updatedVisibility = modelVisibility
        updatedVisibility[modelName] = isVisible
        modelVisibility = updatedVisibility
    }
    
    // MARK: - Hotkey Management
    
    func getHotKeyConfig() -> (keyCode: UInt32, modifiers: UInt32) {
        return (hotkeyKeyCode, hotkeyModifiers)
    }
    
    func setHotKey(keyCode: UInt32, modifiers: UInt32) {
        // Update in-memory
        hotkeyKeyCode = keyCode
        hotkeyModifiers = modifiers
        
        // Persist
        UserDefaults.standard.set(Int(keyCode), forKey: "hotkeyKeyCode")
        UserDefaults.standard.set(Int(modifiers), forKey: "hotkeyModifiers")
        
        // Notify observers (KeyboardShortcutManager will re-register)
        objectWillChange.send()
        NotificationCenter.default.post(name: Notification.Name("HotkeyChanged"), object: nil)
    }
    
    func resetHotKeyToDefault() {
        setHotKey(keyCode: defaultsHotkeyKeyCode, modifiers: defaultsHotkeyModifiers)
    }
    
    func currentHotKeyDisplayString() -> String {
        return Self.displayString(forKeyCode: hotkeyKeyCode, modifiers: hotkeyModifiers)
    }
    
    static func displayString(forKeyCode keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        
        let key = Self.keyCodeToString(keyCode)
        parts.append(key)
        return parts.joined()
    }
    
    private static func keyCodeToString(_ keyCode: UInt32) -> String {
        // Letters
        let mapping: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
            UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
            UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
            UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
            UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
            UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
            UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
            UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
            UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
            UInt32(kVK_ANSI_9): "9",
            UInt32(kVK_Escape): "⎋",
            UInt32(kVK_Space): "Space",
            UInt32(kVK_Return): "↩",
            UInt32(kVK_Tab): "⇥",
            UInt32(kVK_Delete): "⌫",
        ]
        if let str = mapping[keyCode] { return str }
        // Function keys
        if keyCode >= 122 && keyCode <= 126 { // arrows region, handled later if needed
            return ""
        }
        if keyCode >= UInt32(kVK_F1) && keyCode <= UInt32(kVK_F20) {
            let index = Int(keyCode - UInt32(kVK_F1)) + 1
            return "F\(index)"
        }
        return "Key"
    }
    
    static func letterToKeyCode(_ letter: String) -> UInt32? {
        let upper = letter.uppercased()
        let map: [String: UInt32] = [
            "A": UInt32(kVK_ANSI_A), "B": UInt32(kVK_ANSI_B), "C": UInt32(kVK_ANSI_C),
            "D": UInt32(kVK_ANSI_D), "E": UInt32(kVK_ANSI_E), "F": UInt32(kVK_ANSI_F),
            "G": UInt32(kVK_ANSI_G), "H": UInt32(kVK_ANSI_H), "I": UInt32(kVK_ANSI_I),
            "J": UInt32(kVK_ANSI_J), "K": UInt32(kVK_ANSI_K), "L": UInt32(kVK_ANSI_L),
            "M": UInt32(kVK_ANSI_M), "N": UInt32(kVK_ANSI_N), "O": UInt32(kVK_ANSI_O),
            "P": UInt32(kVK_ANSI_P), "Q": UInt32(kVK_ANSI_Q), "R": UInt32(kVK_ANSI_R),
            "S": UInt32(kVK_ANSI_S), "T": UInt32(kVK_ANSI_T), "U": UInt32(kVK_ANSI_U),
            "V": UInt32(kVK_ANSI_V), "W": UInt32(kVK_ANSI_W), "X": UInt32(kVK_ANSI_X),
            "Y": UInt32(kVK_ANSI_Y), "Z": UInt32(kVK_ANSI_Z)
        ]
        return map[upper]
    }
    
    static func keyCodeToLetter(_ keyCode: UInt32) -> String? {
        let reverse: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
            UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
            UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
            UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
            UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
            UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z"
        ]
        return reverse[keyCode]
    }
    
    // Legacy fixed shortcuts - retained for compatibility but not used directly
    let shortcuts: [String: String] = [
        "toggleWindow": "⌘E"
    ]
    
    func getShortcut(for key: String) -> String {
        return shortcuts[key] ?? ""
    }
    
    // This method is kept but does nothing - shortcuts were previously fixed
    func setShortcut(_ shortcut: String, for key: String) {
        // No-op for legacy string-based API
    }
    
    // Toggle always on top setting
    func toggleAlwaysOnTop() {
        alwaysOnTop.toggle()
    }
    
    // Set always on top setting directly
    func setAlwaysOnTop(_ value: Bool) {
        // Prevents unnecessary notifications if value hasn't changed
        if alwaysOnTop != value {
            alwaysOnTop = value
            
            // Post notification with delay to ensure all UI updates complete first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                // Post notification again to ensure it's caught by all observers
                NotificationCenter.default.post(name: Notification.Name("AlwaysOnTopChanged"), object: nil)
            }
        }
    }
    
    func resetToDefaults() {
        // Reset model visibility to default
        initializeModelVisibility()
        // Do not reset hotkey here implicitly to avoid surprising the user
    }
    
    // Login item management functionality has been removed to ensure the app never opens at login
}

// MARK: - Pinned Position Persistence
@available(macOS 11.0, *)
extension PreferencesManager {
    private var pinnedFrameKey: String { "pinnedFrame" }
    
    func savePinnedFrame(_ frame: CGRect) {
        let dict: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "w": frame.size.width,
            "h": frame.size.height
        ]
        UserDefaults.standard.set(dict, forKey: pinnedFrameKey)
    }
    
    func getPinnedFrame() -> CGRect? {
        guard let dict = UserDefaults.standard.dictionary(forKey: pinnedFrameKey) as? [String: CGFloat],
              let x = dict["x"], let y = dict["y"], let w = dict["w"], let h = dict["h"] else {
            return nil
        }
        return CGRect(x: x, y: y, width: w, height: h)
    }
} 
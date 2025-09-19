import Cocoa
import SwiftUI
import ServiceManagement

// MARK: - Launch at Login Manager (SMAppService + legacy fallback)
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
                    print("✅ Removed from login items")
                } else {
                    try SMAppService.mainApp.register()
                    print("✅ Added to login items")
                }
                isEnabled.toggle()
            } catch {
                print("❌ Failed to toggle launch at login: \(error)")
                DispatchQueue.main.async {
                    self.showLoginItemError(error.localizedDescription)
                }
            }
        } else {
            if isEnabled {
                removeFromLoginItems()
            } else {
                addToLoginItems()
            }
        }
    }
    
    // MARK: - Legacy Support (macOS 12 and earlier)
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
        if result != nil {
            isEnabled = true
            print("✅ Added to login items (legacy)")
        } else {
            print("❌ Failed to add to login items (legacy)")
        }
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
                    print("✅ Removed from login items (legacy)")
                    return
                }
            }
        }
    }
    
    private func showLoginItemError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Launch at Login Error"
        alert.informativeText = "Failed to update launch at login setting: \(message)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
} 
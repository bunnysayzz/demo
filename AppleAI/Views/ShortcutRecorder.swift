import SwiftUI
import Carbon.HIToolbox

struct ShortcutRecorder: NSViewRepresentable {
    final class Coordinator: NSObject {
        var onCapture: (UInt32, UInt32) -> Void
        var onCancel: () -> Void
        
        init(onCapture: @escaping (UInt32, UInt32) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }
    }
    
    let placeholder: String
    let onCapture: (UInt32, UInt32) -> Void
    let onCancel: () -> Void
    
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture, onCancel: onCancel) }
    
    func makeNSView(context: Context) -> NSTextField {
        let field = CaptureField(frame: .zero)
        field.placeholderString = placeholder
        field.isBezeled = true
        field.isEditable = false
        field.isSelectable = false
        field.focusRingType = .default
        field.drawsBackground = true
        field.bezelStyle = .roundedBezel
        field.wantsLayer = true
        field.layer?.cornerRadius = 6
        field.onCapture = { keyCode, mods in
            context.coordinator.onCapture(keyCode, mods)
        }
        field.onCancel = {
            context.coordinator.onCancel()
        }
        
        // Make first responder on click
        let click = NSClickGestureRecognizer(target: field, action: #selector(CaptureField.startCapture))
        field.addGestureRecognizer(click)
        
        return field
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {}
}

final class CaptureField: NSTextField {
    var onCapture: ((UInt32, UInt32) -> Void)?
    var onCancel: (() -> Void)?
    private var capturing = false
    
    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        window?.makeFirstResponder(self)
        return true
    }
    
    @objc func startCapture() {
        if !capturing {
            capturing = true
            stringValue = "Press shortcut…"
            window?.makeFirstResponder(self)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        guard capturing else { super.keyDown(with: event); return }
        
        // Build modifiers: allow only control/option/command (+ optional shift)
        var mods: UInt32 = 0
        if event.modifierFlags.contains(.control) { mods |= UInt32(controlKey) }
        if event.modifierFlags.contains(.option) { mods |= UInt32(optionKey) }
        if event.modifierFlags.contains(.command) { mods |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.shift) { mods |= UInt32(shiftKey) }
        
        // Require at least one of control/option/command
        if mods & (UInt32(controlKey) | UInt32(optionKey) | UInt32(cmdKey)) == 0 {
            NSSound.beep()
            stringValue = "Add Ctrl/Opt/Cmd"
            return
        }
        
        // Disallow common macOS-reserved combos
        if isReserved(keyCode: event.keyCode, modifiers: mods) {
            NSSound.beep()
            stringValue = "Reserved, try another"
            return
        }
        
        // Capture and finish
        onCapture?(UInt32(event.keyCode), mods)
        capturing = false
    }
    
    override func flagsChanged(with event: NSEvent) {
        // Ignore
    }
    
    override func cancelOperation(_ sender: Any?) {
        capturing = false
        onCancel?()
    }
    
    private func isReserved(keyCode: UInt16, modifiers: UInt32) -> Bool {
        // Examples of reserved when used with Command: Q, W, H, M, Tab, Space
        let cmd = (modifiers & UInt32(cmdKey)) != 0
        if cmd {
            let reservedKeys: Set<UInt16> = [
                UInt16(kVK_ANSI_Q), // Quit
                UInt16(kVK_ANSI_W), // Close window/tab
                UInt16(kVK_ANSI_M), // Minimize
                UInt16(kVK_Tab),    // Next responder
                UInt16(kVK_Space),  // Spotlight / Quick Look contexts
            ]
            if reservedKeys.contains(keyCode) { return true }
        }
        // Disallow plain Command alone with letters often used by menus
        if cmd {
            let menuLetters: Set<UInt16> = [
                UInt16(kVK_ANSI_C), UInt16(kVK_ANSI_V), UInt16(kVK_ANSI_X), UInt16(kVK_ANSI_Z),
                UInt16(kVK_ANSI_A), UInt16(kVK_ANSI_S), UInt16(kVK_ANSI_P), UInt16(kVK_ANSI_O),
                UInt16(kVK_ANSI_N), UInt16(kVK_ANSI_T)
            ]
            if menuLetters.contains(keyCode) { return true }
        }
        return false
    }
}

func displayStringFor(keyCode: UInt32, modifiers: UInt32) -> String {
    PreferencesManager.displayString(forKeyCode: keyCode, modifiers: modifiers)
}

#Preview {
    VStack(spacing: 8) {
        Text("Recorder Preview")
        ShortcutRecorder(
            placeholder: "Press new shortcut",
            onCapture: { _, _ in },
            onCancel: {}
        )
        .frame(width: 180, height: 24)
    }
    .padding()
} 
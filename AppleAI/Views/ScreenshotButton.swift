import SwiftUI
import AppKit

struct ScreenshotButton: View {
    var window: NSWindow
    
    var body: some View {
        Button(action: {
            takeScreenshot()
        }) {
            Image(systemName: "camera")
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.secondary)
                .frame(width: 16, height: 16)
                .help("Take Screenshot")
        }
        .buttonStyle(BorderlessButtonStyle())
    }
    
    // Function to take a screenshot
    private func takeScreenshot() {
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
            
            // Make window visible again if it was visible before
            if wasVisible {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

// Preview provider for SwiftUI canvas
struct ScreenshotButton_Previews: PreviewProvider {
    static var previews: some View {
        ScreenshotButton(window: NSWindow())
            .padding()
            .previewLayout(.sizeThatFits)
    }
} 
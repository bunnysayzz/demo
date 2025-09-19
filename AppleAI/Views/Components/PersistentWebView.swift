import SwiftUI
import WebKit
import AppKit

/// Enhanced persistent web view with theme integration and improved performance
struct PersistentWebView: NSViewRepresentable {
    let service: AIService
    @Binding var isLoading: Bool
    
    @StateObject private var theme = ThemeManager.shared
    @State private var webView: WKWebView?
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true
        
        // Get or create the web view from cache
        let webView = WebViewCache.shared.webView(for: service)
        self.webView = webView
        
        // Set up the web view in the container
        webView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: containerView.topAnchor),
            webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Apply theme-aware styling
        applyTheme(to: containerView)
        
        // Set up loading state monitoring
        setupLoadingStateMonitoring(webView)
        
        // Create keyboard responder view for better input handling
        let keyboardResponder = KeyboardResponderView()
        keyboardResponder.webView = webView
        containerView.addSubview(keyboardResponder)
        
        NSLayoutConstraint.activate([
            keyboardResponder.topAnchor.constraint(equalTo: containerView.topAnchor),
            keyboardResponder.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            keyboardResponder.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            keyboardResponder.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Apply theme updates
        applyTheme(to: nsView)
        
        // Update loading state
        if let webView = webView {
            DispatchQueue.main.async {
                self.isLoading = webView.isLoading
            }
        }
    }
    
    private func applyTheme(to view: NSView) {
        // Apply theme-based background color
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // Update web view appearance if needed
        if let webView = webView {
            updateWebViewAppearance(webView)
        }
    }
    
    private func updateWebViewAppearance(_ webView: WKWebView) {
        // Inject CSS to match the current theme
        let isDark = theme.effectiveAppearance == .darkAqua
        let accentColorHex = theme.accentColor.nsColor.hexString
        
        let themeCSS = """
        (function() {
            const isDark = \(isDark);
            const accentColor = '\(accentColorHex)';
            
            // Create or update theme style element
            let themeStyle = document.getElementById('apple-ai-theme');
            if (!themeStyle) {
                themeStyle = document.createElement('style');
                themeStyle.id = 'apple-ai-theme';
                document.head.appendChild(themeStyle);
            }
            
            // Define theme-aware CSS
            const css = `
                :root {
                    --apple-ai-accent: ${accentColor};
                    --apple-ai-bg: ${isDark ? '#1e1e1e' : '#ffffff'};
                    --apple-ai-surface: ${isDark ? '#2a2a2a' : '#f5f5f5'};
                }
                
                /* Subtle enhancements for better integration */
                body {
                    transition: background-color 0.3s ease;
                }
                
                /* Custom scrollbar styling */
                ::-webkit-scrollbar {
                    width: 8px;
                    height: 8px;
                }
                
                ::-webkit-scrollbar-track {
                    background: transparent;
                }
                
                ::-webkit-scrollbar-thumb {
                    background: ${isDark ? 'rgba(255,255,255,0.3)' : 'rgba(0,0,0,0.3)'};
                    border-radius: 4px;
                }
                
                ::-webkit-scrollbar-thumb:hover {
                    background: ${isDark ? 'rgba(255,255,255,0.5)' : 'rgba(0,0,0,0.5)'};
                }
            `;
            
            themeStyle.textContent = css;
        })();
        """
        
        webView.evaluateJavaScript(themeCSS) { _, error in
            if let error = error {
                print("Error applying theme CSS: \(error)")
            }
        }
    }
    
    private func setupLoadingStateMonitoring(_ webView: WKWebView) {
        // Monitor loading state changes
        webView.publisher(for: \.isLoading)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                self?.isLoading = loading
                WebViewCache.shared.setLoading(loading, for: service)
            }
            .store(in: &context.coordinator.cancellables)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: PersistentWebView
        var cancellables = Set<AnyCancellable>()
        
        init(_ parent: PersistentWebView) {
            self.parent = parent
        }
    }
}

/// Enhanced keyboard responder view for better web view input handling
class KeyboardResponderView: NSView {
    weak var webView: WKWebView?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }
    
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
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Make this view focusable but transparent
        canDrawSubviewsIntoLayer = true
        
        // Set up tracking area for mouse events
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func mouseDown(with event: NSEvent) {
        // Pass mouse events to the web view and make it first responder
        if let webView = webView {
            window?.makeFirstResponder(webView)
            webView.mouseDown(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        // Enhanced keyboard handling with better focus management
        guard let webView = webView else {
            super.keyDown(with: event)
            return
        }
        
        // Make sure web view is first responder for key events
        if window?.firstResponder != webView {
            window?.makeFirstResponder(webView)
        }
        
        // Pass the event to the web view
        webView.keyDown(with: event)
    }
    
    override func becomeFirstResponder() -> Bool {
        // When this view becomes first responder, delegate to web view
        if let webView = webView {
            return window?.makeFirstResponder(webView) ?? false
        }
        return super.becomeFirstResponder()
    }
    
    override func mouseEntered(with event: NSEvent) {
        // Ensure proper cursor handling
        NSCursor.arrow.set()
    }
}

// MARK: - Extensions

extension NSColor {
    /// Convert NSColor to hex string for CSS injection
    var hexString: String {
        guard let rgbColor = usingColorSpace(.deviceRGB) else {
            return "#000000"
        }
        
        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))
        
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

import Combine

extension WKWebView {
    /// Publisher for loading state changes
    func publisher<T>(for keyPath: KeyPath<WKWebView, T>) -> AnyPublisher<T, Never> {
        publisher(for: keyPath, options: [.initial, .new])
            .map(\.newValue)
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
}
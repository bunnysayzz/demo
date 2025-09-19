@preconcurrency
import SwiftUI
import WebKit
import Combine
import AVFoundation
import Network

// Global WebView cache to store and reuse webviews
class WebViewCache: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    static let shared = WebViewCache()
    
    @Published private var webViews: [String: WKWebView] = [:]
    @Published var loadingStates: [String: Bool] = [:]
    private var chatGPTTimers: [WKWebView: Timer] = [:] // Track timers to avoid duplicates
    
    // Track when a file picker is active to prevent window hiding
    @Published var isFilePickerActive: Bool = false
    
    // Track voice chat activity state
    private var isVoiceChatActive: Bool = false
    
    private var lastVoiceActivityTime: Date? = nil
    
    // Add currentServiceID property to track the active service
    private var currentServiceID: String? = nil
    
    // MARK: - Network reachability for auto-reload
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "WebViewCache.NetworkMonitor")
    private var hasNetworkConnectivity: Bool = true
    private var pendingReloadServiceIds: Set<String> = []
    
    private override init() {
        super.init()
        // Preload all service webviews on initialization
        preloadWebViews()
        
        // Pre-request microphone permission at app startup
        DispatchQueue.main.async {
            self.requestMicrophonePermission()
        }
        
        // Add notification observer for Gemini API key updates
        NotificationCenter.default.addObserver(self, 
                                               selector: #selector(applyGeminiAPIKey), 
                                               name: NSNotification.Name("ApplyGeminiAPIKey"), 
                                               object: nil)
        
        // Add notification observer for reloading askAppleAI WebView when API key changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadAskAppleAIWebView),
                                               name: NSNotification.Name("ReloadAskAppleAIWebView"),
                                               object: nil)
        
        // Add notification observer for direct API key changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(geminiAPIKeyChanged),
                                               name: NSNotification.Name("GeminiAPIKeyChanged"),
                                               object: nil)
        
        // Start network monitoring to recover from offline-at-login blank loads
        startNetworkMonitoring()
    }
    
    // Handle direct Gemini API key changes
    @objc func geminiAPIKeyChanged(_ notification: Notification) {
        // Always reload the askAppleAI WebView when API key changes (empty or filled)
        print("Detected Gemini API key change - forcing WebView reload")
        
        // Force reload by calling our reload method
        let reloadNotification = Notification(name: NSNotification.Name("ReloadAskAppleAIWebView"), object: "askAppleAI")
        reloadAskAppleAIWebView(reloadNotification)
    }
    
    // Handle the ReloadAskAppleAIWebView notification
    @objc func reloadAskAppleAIWebView(_ notification: Notification) {
        // Find the askAppleAI service by name, using the notification object
        if let serviceName = notification.object as? String,
           serviceName == "askAppleAI",
           // Find the service in aiServices array
           let askAppleAIService = aiServices.first(where: { $0.name == "askAppleAI" }),
           // Get the WebView for this service
           let webView = webViews[askAppleAIService.id.uuidString] {
            
            // Get URL from the documents directory for the Gemini HTML
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let geminiURL = documentsDirectory.appendingPathComponent("GeminiChat", isDirectory: true).appendingPathComponent("index.html")
            
            if fileManager.fileExists(atPath: geminiURL.path) {
                // Check if API key exists in UserDefaults
                let apiKey = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
                
                // Use cache policy to ensure we get the latest content - this will force a complete reload
                // which will show either the API key message or the chat interface based on current API key status
                let request = URLRequest(url: geminiURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
                webView.load(request)
                
                // Update loading state
                loadingStates[askAppleAIService.id.uuidString] = true
                
                print("Reloading askAppleAI WebView due to API key change - API Key is \(apiKey.isEmpty ? "empty" : "set")")
            }
        }
    }
    
    // Function to explicitly request microphone permission
    func requestMicrophonePermission() {
        // Check if we've already requested microphone permission
        let audioSession = AVCaptureDevice.authorizationStatus(for: .audio)
        
        // Only request permission if not already determined
        if audioSession == .notDetermined {
            print("Microphone permission not determined, requesting access")
            
            // Request permission
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    print("Microphone permission granted")
                } else {
                    print("Microphone permission denied")
                }
            }
        } else if audioSession == .authorized {
            print("Microphone permission already granted")
        } else if audioSession == .denied {
            print("Microphone permission already denied")
            
            // Show a message to the user explaining how to enable the permission
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Microphone Access Required"
                alert.informativeText = "Apple AI needs microphone access for voice chat features. Please enable it in System Settings > Privacy & Security > Microphone."
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    // Open the Privacy & Security settings for microphone
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } else if audioSession == .restricted {
            print("Microphone access is restricted")
        }
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Handle script messages from the webview, especially for permissions
        if message.name == "mediaPermission" {
            print("Received message from JavaScript: \(message.body)")
            
            // If we received a message about permissions, log it but don't trigger keychain prompts
            if let messageBody = message.body as? [String: Any],
               let messageType = messageBody["type"] as? String {
                
                switch messageType {
                case "permissionDenied", "streamError", "permissionError":
                    // Log the error but don't show a system dialog that might trigger keychain
                    print("Microphone permission issue in webview: \(messageType)")
                    
                    // Request the permission through AVFoundation instead
                    // This avoids keychain prompts
                    let audioSession = AVCaptureDevice.authorizationStatus(for: .audio)
                    if audioSession == .authorized {
                        // Inject script to work around permission issues
                        injectPermissionFixer(message.webView)
                    }
                    
                    // Also set voice chat as inactive since there was an error
                    setVoiceChatActive(false)
                    
                case "voiceButtonClicked":
                    // Voice button was clicked, handle it silently
                    print("Voice button clicked in UI")
                    
                    // Set voice chat as active
                    setVoiceChatActive(true)
                    
                    // Start monitoring this webview for voice UI changes
                    if let webView = message.webView {
                        injectVoiceChatActivityDetector(webView)
                    }
                    
                case "voiceChatStarted", "voiceInputActive", "recordingStarted":
                    // Voice recording is active
                    print("Voice recording started: \(messageType)")
                    setVoiceChatActive(true)
                    
                    // Start monitoring for UI changes
                    if let webView = message.webView {
                        injectVoiceChatActivityDetector(webView)
                    }
                    
                case "permissionGranted", "streamCreated":
                    print("Microphone permission success: \(messageType)")
                    
                    // When stream is created, voice chat is active
                    setVoiceChatActive(true)
                    
                    // Monitor this stream to detect when it ends
                    if let webView = message.webView {
                        monitorStreamStatus(webView, streamInfo: messageBody)
                    }
                    
                case "streamEnded", "voiceChatStopped", "audioStopped", "recordingStopped":
                    print("Microphone stream ended: \(messageType)")
                    
                    // When stream ends, voice chat is no longer active
                    setVoiceChatActive(false)
                    
                    // Reason for stopping (if provided)
                    let reason = messageBody["reason"] as? String ?? "unknown"
                    print("Stream ended reason: \(reason)")
                    
                    // Perform immediate cleanup for explicit user actions
                    if reason == "userClosed" || reason == "escKey" || reason == "uiClosed" || reason == "stopButton" {
                        // For explicit user actions, stop microphone immediately
                        if let webView = message.webView {
                            injectAudioStopScript(webView)
                        } else {
                            stopAllMicrophoneUse()
                        }
                    } else {
                        // For other reasons, delay cleanup to avoid interrupting quick reconnections
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                            guard let self = self, !self.isVoiceChatActive else { return }
                            self.stopAllMicrophoneUse()
                        }
                    }
                    
                case "voiceActivityDetected":
                    // Voice activity is still ongoing - update the last activity time
                    lastVoiceActivityTime = Date()
                    
                case "uiClosed", "voiceUIClosed":
                    // Voice UI has closed - stop voice chat after a short delay
                    print("Voice UI has closed")
                    
                    // Set voice chat inactive after a brief delay to catch quick reopening
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self = self else { return }
                        self.setVoiceChatActive(false)
                        
                        // Stop microphone use after 1 second if voice chat doesn't resume
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                            guard let self = self, !self.isVoiceChatActive else { return }
                            self.stopAllMicrophoneUse()
                        }
                    }
                    
                default:
                    print("Unknown media permission message: \(messageType)")
                }
            }
        }
    }
    
    // Function to inject a dedicated voice chat activity detector
    private func injectVoiceChatActivityDetector(_ webView: WKWebView) {
        let script = """
        (function() {
            // Check if detector is already running
            if (window._voiceChatActivityDetectorRunning) return;
            window._voiceChatActivityDetectorRunning = true;
            
            console.log('Voice chat activity detector started');
            
            // Function to check if voice chat UI is visible
            function isVoiceChatUIVisible() {
                // ChatGPT voice chat elements
                const chatGPTElements = document.querySelectorAll('[aria-label="Stop recording"], [aria-label="Voice input enabled"], .voice-input-active, .recording-button-active, [data-testid="voice-message-recording-indicator"]');
                
                // Microsoft Copilot voice elements
                const copilotElements = document.querySelectorAll('[aria-label="Stop voice input"], .voice-input-container:not(.hidden), [data-testid="voice-input-button"].active');
                
                // Claude voice elements
                const claudeElements = document.querySelectorAll('.voice-recording-active, .recording-indicator-active, [data-recording="true"]');
                
                // Generic voice UI elements
                const genericElements = document.querySelectorAll('.voice-recording, .microphone-active, .recording-active, [data-voice-active="true"], [aria-label*="recording"], [aria-label*="voice"], .voice-button.active');
                
                return chatGPTElements.length > 0 || copilotElements.length > 0 || claudeElements.length > 0 || genericElements.length > 0;
            }
            
            // Keep track of previous voice UI state
            let wasVoiceChatVisible = isVoiceChatUIVisible();
            let lastActiveTime = Date.now();
            
            // Check for voice chat UI changes every 500ms
            const checkInterval = 500; // ms
            const activityTimeout = 1000; // If no activity for 1 second, consider voice chat inactive
            
            // Register listeners for stop buttons
            function registerStopButtonListeners() {
                // Look for stop/close buttons in voice chat UI
                const stopButtons = document.querySelectorAll(
                    '[aria-label="Stop recording"], [aria-label="Stop voice input"], .voice-stop-button, .close-voice-button, ' +
                    'button.voice-close, [data-testid="voice-stop-button"], [aria-label="Stop listening"]'
                );
                
                // Add click listeners to stop buttons if found
                stopButtons.forEach(button => {
                    if (!button._hasVoiceStopListener) {
                        button._hasVoiceStopListener = true;
                        button.addEventListener('click', () => {
                            console.log('Voice chat stop button clicked');
                            
                            // Notify Swift that voice chat was explicitly stopped
                            window.webkit.messageHandlers.mediaPermission.postMessage({
                                type: 'voiceChatStopped',
                                reason: 'stopButton'
                            });
                            
                            // Force stop any active audio in the page
                            stopAllAudioTracks();
                        });
                    }
                });
            }
            
            // Helper function to stop all audio tracks
            function stopAllAudioTracks() {
                if (window.activeAudioStreams) {
                    console.log('Stopping all audio tracks from voice chat detector');
                    window.activeAudioStreams.forEach(stream => {
                        if (stream && typeof stream.getTracks === 'function') {
                            stream.getTracks().forEach(track => {
                                if (track.kind === 'audio') {
                                    console.log('Stopping audio track');
                                    track.stop();
                                    track.enabled = false;
                                }
                            });
                        }
                    });
                    
                    // Clear the active streams array
                    window.activeAudioStreams = [];
                }
            }
            
            // Setup periodic check for voice UI changes
            const voiceUIInterval = setInterval(() => {
                // Check current state of voice chat UI
                const isVoiceChatVisible = isVoiceChatUIVisible();
                
                // If voice chat is visible
                if (isVoiceChatVisible) {
                    // Update last active time
                    lastActiveTime = Date.now();
                    
                    // If voice chat newly appeared
                    if (!wasVoiceChatVisible) {
                        console.log('Voice chat UI detected - voice chat active');
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'voiceChatStarted',
                            reason: 'uiDetected'
                        });
                    } else {
                        // Send periodic voice activity heartbeat
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'voiceActivityDetected'
                        });
                    }
                    
                    // Always register for stop buttons when UI is visible
                    registerStopButtonListeners();
                }
                // If voice chat was visible but now it's not
                else if (wasVoiceChatVisible) {
                    console.log('Voice chat UI disappeared');
                    
                    // Notify that the UI closed
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'uiClosed'
                    });
                    
                    // Force stop audio tracks after UI disappears
                    stopAllAudioTracks();
                }
                // If voice chat wasn't visible last check but activity was recent
                else if (Date.now() - lastActiveTime < activityTimeout) {
                    // Voice chat activity was recent but UI not visible, check for stop buttons
                    registerStopButtonListeners();
                }
                
                // Update previous state
                wasVoiceChatVisible = isVoiceChatVisible;
            }, checkInterval);
            
            // Also monitor ESC key as it's often used to close voice dialog
            document.addEventListener('keydown', (e) => {
                if (e.key === 'Escape' && wasVoiceChatVisible) {
                    console.log('ESC key pressed while voice chat was active');
                    
                    // Check after a small delay if voice UI disappeared
                    setTimeout(() => {
                        if (!isVoiceChatUIVisible()) {
                            console.log('Voice chat closed by ESC key');
                            window.webkit.messageHandlers.mediaPermission.postMessage({
                                type: 'voiceChatStopped',
                                reason: 'escKey'
                            });
                            
                            // Stop any audio tracks
                            stopAllAudioTracks();
                        }
                    }, 100);
                }
            });
            
            // Clean up resources if the window or tab is closed
            window.addEventListener('beforeunload', () => {
                clearInterval(voiceUIInterval);
                window._voiceChatActivityDetectorRunning = false;
                console.log('Voice chat detector cleaned up');
                
                // Stop any audio tracks
                stopAllAudioTracks();
            });
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error injecting voice chat activity detector: \(error)")
            } else {
                print("Successfully injected voice chat activity detector")
            }
        }
    }
    
    // Monitor stream status to detect when it ends
    private func monitorStreamStatus(_ webView: WKWebView, streamInfo: [String: Any]) {
        // Add a script to monitor the status of this stream and all tracks
        let script = """
        (function() {
            // Helper function to add track monitoring
            function addTrackMonitoring(stream) {
                // Check if this stream has audio tracks
                const audioTracks = stream.getAudioTracks ? stream.getAudioTracks() : [];
                
                if (audioTracks.length > 0) {
                    console.log('Monitoring', audioTracks.length, 'audio tracks for end events');
                    
                    // Add listeners to all tracks
                    audioTracks.forEach(track => {
                        // Add ended event listener if not already added
                        if (!track._endedListenerAdded) {
                            track._endedListenerAdded = true;
                            
                            track.addEventListener('ended', function() {
                                console.log('Audio track ended');
                                window.webkit.messageHandlers.mediaPermission.postMessage({
                                    type: 'streamEnded',
                                    reason: 'trackEnded'
                                });
                            });
                            
                            // Also monitor muted state
                            track.addEventListener('mute', function() {
                                console.log('Audio track muted');
                                window.webkit.messageHandlers.mediaPermission.postMessage({
                                    type: 'trackMuted'
                                });
                            });
                            
                            // Monitor for enabled/disabled state
                            const originalEnabled = track.enabled;
                            Object.defineProperty(track, 'enabled', {
                                get: function() { return originalEnabled; },
                                set: function(value) {
                                    if (!value && originalEnabled) {
                                        console.log('Audio track disabled');
                                        window.webkit.messageHandlers.mediaPermission.postMessage({
                                            type: 'trackDisabled'
                                        });
                                    }
                                    originalEnabled = value;
                                }
                            });
                        }
                    });
                }
                
                // Add listener for stream's inactive event
                if (!stream._inactiveListenerAdded) {
                    stream._inactiveListenerAdded = true;
                    
                    stream.addEventListener('inactive', function() {
                        console.log('Stream became inactive');
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'streamEnded',
                            reason: 'inactive'
                        });
                    });
                    
                    // Also add monitor for removeTrack
                    stream.addEventListener('removetrack', function(e) {
                        console.log('Track removed from stream:', e.track.kind);
                        if (e.track.kind === 'audio') {
                            window.webkit.messageHandlers.mediaPermission.postMessage({
                                type: 'trackRemoved'
                            });
                        }
                    });
                }
            }
            
            // Find all active streams to monitor
            if (window.activeAudioStreams && window.activeAudioStreams.length > 0) {
                // Add monitoring to all active streams
                window.activeAudioStreams.forEach(stream => {
                    if (stream) {
                        addTrackMonitoring(stream);
                    }
                });
                
                // Success - at least one stream was found
                return true;
            } else {
                // No active streams found to monitor
                console.log('No active streams found to monitor');
                return false;
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error monitoring audio stream: \(error)")
            } else if let success = result as? Bool, success {
                print("Successfully added stream monitoring")
            } else {
                print("No streams found to monitor")
            }
        }
    }
    
    deinit {
        // Clean up all timers
        for timer in chatGPTTimers.values {
            timer.invalidate()
        }
        networkMonitor.cancel()
    }
    
    // MARK: - Notification Handlers
    
    @objc func applyGeminiAPIKey() {
        // Get the API key from UserDefaults
        let apiKey = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
        
        // Only proceed if we have a valid API key
        guard !apiKey.isEmpty else { return }
        
        // Find the askAppleAI service
        if let askAppleAIService = aiServices.first(where: { $0.name == "askAppleAI" }) {
            let serviceId = askAppleAIService.id.uuidString
            
            // If we already have a webview for this service, reload it
            if let existingWebView = webViews[serviceId] {
                // Clear any existing webview
                existingWebView.stopLoading()
                
                // Create the Gemini HTML files directory if needed
                let fileManager = FileManager.default
                let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                let geminiDir = documentsURL.appendingPathComponent("GeminiChat")
                try? fileManager.createDirectory(at: geminiDir, withIntermediateDirectories: true, attributes: nil)
                
                // Create a basic HTML file with the API key embedded
                let htmlPath = geminiDir.appendingPathComponent("index.html")
                let htmlContent = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>askAppleAI Gemini Chat</title>
                    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
                    <script src="https://cdn.jsdelivr.net/npm/dompurify@3.0.5/dist/purify.min.js"></script>
                    <style>
                        body {
                            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
                            margin: 0;
                            padding: 0;
                            height: 100vh;
                            display: flex;
                            flex-direction: column;
                            background-color: #f5f5f7;
                        }
                        .chat-container {
                            flex: 1;
                            display: flex;
                            flex-direction: column;
                            padding: 16px;
                            overflow-y: auto;
                        }
                        .message {
                            max-width: 70%;
                            margin-bottom: 12px;
                            padding: 10px 14px;
                            border-radius: 18px;
                            line-height: 1.4;
                        }
                        .user-message {
                            align-self: flex-end;
                            background-color: #007aff;
                            color: white;
                            margin-left: auto;
                        }
                        .ai-message {
                            background-color: #e5e5ea;
                            color: black;
                            margin-right: auto;
                        }
                        .input-area {
                            display: flex;
                            padding: 16px;
                            background-color: white;
                            border-top: 1px solid #ddd;
                        }
                        #user-input {
                            flex: 1;
                            padding: 12px;
                            border: 1px solid #ccc;
                            border-radius: 24px;
                            font-size: 16px;
                            margin-right: 8px;
                        }
                        button {
                            background-color: #007aff;
                            color: white;
                            border: none;
                            border-radius: 50%;
                            width: 40px;
                            height: 40px;
                            font-size: 18px;
                            cursor: pointer;
                            display: flex;
                            align-items: center;
                            justify-content: center;
                        }
                        .typing-indicator {
                            display: none;
                            padding: 10px 14px;
                            background-color: #e5e5ea;
                            border-radius: 18px;
                            margin-bottom: 12px;
                            width: fit-content;
                        }
                        .dot {
                            display: inline-block;
                            width: 8px;
                            height: 8px;
                            background-color: #777;
                            border-radius: 50%;
                            margin-right: 3px;
                            animation: bounce 1.4s infinite ease-in-out;
                        }
                        .dot:nth-child(1) { animation-delay: 0s; }
                        .dot:nth-child(2) { animation-delay: 0.2s; }
                        .dot:nth-child(3) { animation-delay: 0.4s; }
                        @keyframes bounce {
                            0%, 80%, 100% { transform: translateY(0); }
                            40% { transform: translateY(-8px); }
                        }
                    </style>
                </head>
                <body>
                    <div class="chat-container" id="chat-container">
                        <div class="message ai-message">Hello! I'm Gemini, how can I help you today?</div>
                        <div class="typing-indicator" id="typing-indicator">
                            <span class="dot"></span>
                            <span class="dot"></span>
                            <span class="dot"></span>
                        </div>
                    </div>
                    <div class="input-area">
                        <input type="text" id="user-input" placeholder="Type your message here..." autofocus>
                        <button id="send-button">↑</button>
                    </div>
                    
                    <script>
                        // Store the Gemini API key
                        const API_KEY = '\(apiKey)';
                        const chatContainer = document.getElementById('chat-container');
                        const userInput = document.getElementById('user-input');
                        const sendButton = document.getElementById('send-button');
                        const typingIndicator = document.getElementById('typing-indicator');
                        
                        // Add event listeners
                        sendButton.addEventListener('click', sendMessage);
                        userInput.addEventListener('keypress', function(e) {
                            if (e.key === 'Enter') {
                                sendMessage();
                            }
                        });
                        
                        // Function to send a message
                        function sendMessage() {
                            const message = userInput.value.trim();
                            if (message === '') return;
                            
                            // Add user message to chat
                            addMessage(message, 'user');
                            userInput.value = '';
                            
                            // Show typing indicator
                            typingIndicator.style.display = 'block';
                            chatContainer.scrollTop = chatContainer.scrollHeight;
                            
                            // Call Gemini API
                            callGeminiAPI(message);
                        }
                        
                        // Function to add a message to the chat
                        function addMessage(text, sender) {
                            const messageDiv = document.createElement('div');
                            messageDiv.classList.add('message');
                            messageDiv.classList.add(sender === 'user' ? 'user-message' : 'ai-message');
                            
                            // For AI messages, render markdown. For user messages, use plain text
                            if (sender === 'ai') {
                                // Use marked to render markdown and DOMPurify to sanitize HTML
                                const sanitizedHTML = DOMPurify.sanitize(marked.parse(text));
                                messageDiv.innerHTML = sanitizedHTML;
                            } else {
                                messageDiv.textContent = text;
                            }
                            
                            // Insert before the typing indicator
                            chatContainer.insertBefore(messageDiv, typingIndicator);
                            chatContainer.scrollTop = chatContainer.scrollHeight;
                        }
                        
                        // Function to call the Gemini API
                        async function callGeminiAPI(prompt) {
                            try {
                                const response = await fetch('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=' + API_KEY, {
                                    method: 'POST',
                                    headers: {
                                        'Content-Type': 'application/json'
                                    },
                                    body: JSON.stringify({
                                        contents: [{
                                            parts: [{
                                                text: prompt
                                            }]
                                        }]
                                    })
                                });
                                
                                const data = await response.json();
                                
                                // Hide typing indicator
                                typingIndicator.style.display = 'none';
                                
                                // Handle the response
                                if (data.candidates && data.candidates[0] && data.candidates[0].content) {
                                    const aiResponse = data.candidates[0].content.parts[0].text;
                                    addMessage(aiResponse, 'ai');
                                } else if (data.error) {
                                    addMessage('Error: ' + data.error.message, 'ai');
                                } else {
                                    addMessage('Sorry, I couldn\\'t process that request.', 'ai');
                                }
                            } catch (error) {
                                typingIndicator.style.display = 'none';
                                addMessage('Sorry, there was an error communicating with the API: ' + error.message, 'ai');
                            }
                        }
                    </script>
                </body>
                </html>
                """
                
                try? htmlContent.write(to: htmlPath, atomically: true, encoding: .utf8)
                
                // Load the newly created HTML file
                if fileManager.fileExists(atPath: htmlPath.path) {
                    // Reset the webview
                    existingWebView.load(URLRequest(url: htmlPath))
                    
                    // Mark this service as not loading anymore
                    self.loadingStates[serviceId] = false
                    NotificationCenter.default.post(name: NSNotification.Name("WebViewLoadingChanged"), object: nil)
                }
            } else {
                // We need to create a new webview for this service
                // This will trigger the createWebView function which will handle loading the HTML
                _ = getWebView(for: askAppleAIService)
            }
        }
    }
    
    // MARK: - WebView Management
    
    func getWebView(for service: AIService) -> WKWebView {
        // Update the current service ID when accessing a webview
        updateCurrentServiceID(for: service)
        
        let serviceId = service.id.uuidString
        if let existingWebView = webViews[serviceId] {
            // If this is askAppleAI, check if we need to reload with a new API key
            if service.name == "askAppleAI" {
                // Temporarily get gemini API key directly from UserDefaults
                let apiKey = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
                if !apiKey.isEmpty {
                    // Use a placeholder URL for now to get the build working
                    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let htmlURL = documentsURL.appendingPathComponent("GeminiChat/index.html")
                    if FileManager.default.fileExists(atPath: htmlURL.path) {
                        let request = URLRequest(url: htmlURL)
                        existingWebView.load(request)
                    }
                }
            }
            return existingWebView
        }
        
        let webView = createWebView(for: service)
        webViews[serviceId] = webView
        return webView
    }
    
    private func preloadWebViews() {
        // Preload all service webviews
        for service in aiServices {
            // Don't preload askAppleAI until we have an API key
            if service.name == "askAppleAI" {
                let apiKey = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
                if apiKey.isEmpty {
                    continue
                }
            }
            DispatchQueue.main.async {
                _ = self.getWebView(for: service)
            }
        }
    }
    
    func createWebView(for service: AIService) -> WKWebView {
        // Create and configure a WKWebViewConfiguration
        let configuration = WKWebViewConfiguration()
        
        // Set up webpage preferences (macOS preferred way)
        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = pagePreferences
    
        // Allow media playback without user action
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Create a new process pool for this configuration
        configuration.processPool = WKProcessPool()
        
        // Modify user agent to match desktop Safari
        configuration.applicationNameForUserAgent = "Version/15.0 Safari/605.1.15"
    
        // Configure for microphone access
        if #available(macOS 11.0, *) {
            // For macOS 11 and later, use the specific API
            configuration.allowsAirPlayForMediaPlayback = true
            configuration.userContentController.add(self, name: "mediaPermission")
        
            // Add script to request microphone permission immediately
            let immediatePermissionScript = """
            (function() {
                // Don't immediately request microphone permission as this causes repeated prompts
                // Instead, set up a handler that will properly request it when needed
                if (typeof navigator.mediaDevices !== 'undefined') {
                    // Log all permission requests
                const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
                navigator.mediaDevices.getUserMedia = async function(constraints) {
                    console.log('getUserMedia called with:', constraints);
                    
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'getUserMediaCalled',
                        constraints: JSON.stringify(constraints)
                    });
                    
                    try {
                        const stream = await originalGetUserMedia.call(this, constraints);
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'streamCreated',
                            trackCount: stream.getTracks().length
                        });
                        return stream;
                    } catch (err) {
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'streamError',
                            error: err.toString()
                        });
                        throw err;
                    }
                };
                }
            })();
            """
            
            // Add the userScript with immediate execution
            let userScript = WKUserScript(
                source: immediatePermissionScript, 
                injectionTime: .atDocumentStart, 
                forMainFrameOnly: false
            )
            configuration.userContentController.addUserScript(userScript)
        }
        
        // Create the web view
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        // Make background transparent so it blends with system appearance
        webView.setValue(false, forKey: "drawsBackground")
        
        // Special configuration for Microsoft Copilot to handle authentication properly
        if service.name == "Copilot" {
            let request = URLRequest(url: service.url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
            webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15"
            
            // Allow all types of cookies to ensure authentication works properly
            webView.configuration.websiteDataStore = WKWebsiteDataStore.default()
            
            // Ensure 3rd party cookies are allowed
            if #available(macOS 11.0, *) {
                webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
            }
            
            // Load with the custom configuration
            webView.load(request)
        } else if service.name == "askAppleAI" {
            // Always load provider HTML generated by GeminiAPIManager so it respects system dark/light mode
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let htmlURL = documentsURL.appendingPathComponent("GeminiChat/index.html")
            
            // Ensure latest content is generated for current API key state
            GeminiAPIManager.shared.generateGeminiHTML()
            webView.load(URLRequest(url: htmlURL))
        } else {
            // Standard loading for other services
            webView.load(URLRequest(url: service.url))
        }
        
        // Set loading state
        loadingStates[service.id.uuidString] = true
        
        return webView
    }
    
    // MARK: - WKNavigationDelegate Methods
    
    // Add a special method to handle OAuth redirects for Copilot
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Handle Microsoft auth redirects for Copilot
        if let url = navigationAction.request.url, 
           url.host?.contains("login.microsoftonline.com") == true || 
           url.host?.contains("login.live.com") == true || 
           url.host?.contains("login.microsoft.com") == true {
            
            // Always allow Microsoft auth domains
            decisionHandler(.allow)
            return
        }
        
        // If we're navigating to Copilot after authentication, ensure cookies are preserved
        if let url = navigationAction.request.url, 
           url.host?.contains("copilot.microsoft.com") == true {
            // Allow the navigation
            decisionHandler(.allow)
            return
        }
        
        // For other requests, allow normal navigation
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Find the service ID for this webview
        for (serviceId, storedWebView) in webViews {
            if storedWebView === webView {
                DispatchQueue.main.async {
                    self.loadingStates[serviceId] = false
                    self.pendingReloadServiceIds.remove(serviceId)
                }
                
                // Inject keyboard shortcut handlers
                injectKeyboardShortcutHandlers(webView)
                
                // Inject microphone permission handlers
                injectMicrophonePermissionHandlers(webView)
                
                // Inject service-specific handlers
                if let service = aiServices.first(where: { $0.id.uuidString == serviceId }) {
                    injectServiceSpecificHandlers(webView, for: service)
                    
                    // Special handling for Copilot after navigation
                    if service.name == "Copilot" {
                        injectCopilotAuthFixer(webView)
                    }
                }
                
                // Check if this is ChatGPT and inject JavaScript to handle enter key
                if let service = aiServices.first(where: { $0.id.uuidString == serviceId }),
                   service.name == "ChatGPT" {
                    injectChatGPTEnterKeyHandler(webView)
                }
                
                break
            }
        }
    }
    
    // Fix potential auth issues with Copilot
    private func injectCopilotAuthFixer(_ webView: WKWebView) {
        // This script helps prevent redirect_uri mismatches by ensuring the URI is consistent
        let script = """
        (function() {
            // Don't run this script twice
            if (window._copilotAuthFixed) return;
            window._copilotAuthFixed = true;
            
            console.log('Copilot auth helper initialized');
            
            // Fix for redirect_uri issues
            if (window.location.href.includes('login.microsoft') || window.location.href.includes('login.live')) {
                // For Microsoft login pages, ensure the redirect_uri is properly preserved
                console.log('On Microsoft login page, ensuring redirect parameters are preserved');
                
                // Track form submissions to ensure redirect_uri is correct
                document.addEventListener('submit', function(e) {
                    // This is a non-invasive way to ensure auth parameters are preserved
                    if (!e.target.action || !e.target.action.includes('login.microsoft')) return;
                    
                    console.log('Auth form submission detected');
                    
                    // Don't modify anything, just let the normal flow happen
                    // This is just to ensure we have a submit event listener registered
                }, true);
                
                // Ensure WebAuthentication API doesn't cause issues
                if (window.WebAuthentication) {
                    console.log('WebAuthentication API detected, ensuring compatibility');
                }
            }
            
            // For Copilot main page, ensure we're logged in properly
            if (window.location.href.includes('copilot.microsoft.com')) {
                console.log('On Copilot main page, checking auth status');
                
                // Nothing to do here, just logging for debugging
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error injecting Copilot auth fixer: \(error)")
            } else {
                print("Successfully injected Copilot auth fixer")
            }
        }
    }
    
    // Function to inject JavaScript for keyboard shortcuts (copy, paste, select all only)
    private func injectKeyboardShortcutHandlers(_ webView: WKWebView) {
        let script = """
        (function() {
            // Check if we've already injected this script
            if (window._keyboardShortcutsInjected) return;
            window._keyboardShortcutsInjected = true;
            
            // Enhanced copy/paste handling for better reliability
            document.addEventListener('keydown', function(e) {
                // Handle cmd/ctrl+c (copy)
                if ((e.metaKey || e.ctrlKey) && e.key === 'c') {
                    // Log copy event for debugging
                    console.log('Copy shortcut detected, forwarding to system');
                    
                    // Allow the browser's default copy action
                    // Don't prevent default - let the system handle it
                    
                    // Additional handling - try clipboard API for difficult cases
                    try {
                        const selection = window.getSelection();
                        if (selection && selection.toString()) {
                            // We have text selected, try to copy it using clipboard API
                            navigator.clipboard.writeText(selection.toString())
                                .then(() => console.log('Text copied using clipboard API'))
                                .catch(err => console.error('Clipboard API failed:', err));
                        }
                    } catch(e) {
                        console.error('Error in copy handler:', e);
                    }
                }
            }, true);
            
            // Handle copy events directly to ensure they always work
            document.addEventListener('copy', function(e) {
                console.log('Native copy event detected');
                
                // Allow default behavior - don't interfere with system copy
                // This ensures we're not breaking native copy functionality
                
                // If there's no selection, try to find text in focus/active elements
                if (!window.getSelection().toString()) {
                    const activeElement = document.activeElement;
                    
                    if (activeElement && 
                        (activeElement.tagName === 'INPUT' || 
                         activeElement.tagName === 'TEXTAREA' || 
                         activeElement.getAttribute('contenteditable') === 'true')) {
                        
                        // Let the default handler work without interference
                        console.log('Copy in active input field, using native handler');
                    }
                }
            }, false);
            
            console.log('Enhanced keyboard shortcuts applied with special copy handling');
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error injecting keyboard shortcut handlers: \(error)")
            } else {
                print("Successfully injected keyboard shortcut handlers with enhanced copy support")
            }
        }
    }
    
    // Function to inject JavaScript for ChatGPT to make Enter send message
    private func injectChatGPTEnterKeyHandler(_ webView: WKWebView) {
        let script = """
        document.addEventListener('keydown', function(e) {
            // Check if this is the Enter key without shift
            if (e.key === 'Enter' && !e.shiftKey) {
                // Find the send button
                const sendButton = document.querySelector('button[data-testid="send-button"]');
                
                // If we found the send button
                if (sendButton) {
                    // Prevent default action (new line)
                    e.preventDefault();
                    
                    // Click the send button
                    sendButton.click();
                    
                    // Return to prevent further handling
                    return false;
                }
            }
        }, true);
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error injecting ChatGPT Enter key handler: \(error)")
            } else {
                print("Successfully injected ChatGPT Enter key handler")
                
                // Schedule periodic reinjection as ChatGPT is a SPA and might rebuild UI
                self.scheduleChatGPTEnterKeyReinject(webView)
            }
        }
    }
    
    // Function to periodically re-inject the script
    private func scheduleChatGPTEnterKeyReinject(_ webView: WKWebView) {
        // Cancel any existing timer for this webview
        if let existingTimer = chatGPTTimers[webView] {
            existingTimer.invalidate()
            chatGPTTimers.removeValue(forKey: webView)
        }
        
        // Create a new timer
        let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self, weak webView] timer in
            guard let self = self, let webView = webView else {
                timer.invalidate()
                return
            }
            
            // For any service ID that matches ChatGPT, check if the webview is visible
            for (serviceId, storedWebView) in self.webViews {
                if storedWebView === webView,
                   let service = aiServices.first(where: { $0.id.uuidString == serviceId }),
                   service.name == "ChatGPT",
                   !webView.isHidden {
                    // If it's visible, reapply the script
                    let checkScript = """
                    if (!window._chatGPTEnterHandlerActive) {
                        window._chatGPTEnterHandlerActive = true;
                        true;
                    } else {
                        false;
                    }
                    """
                    
                    webView.evaluateJavaScript(checkScript) { (result, error) in
                        if let needsReinject = result as? Bool, needsReinject {
                            self.injectChatGPTEnterKeyHandler(webView)
                        }
                    }
                    
                    break
                }
            }
        }
        
        // Store the timer
        chatGPTTimers[webView] = timer
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Find the service ID for this webview
        for (serviceId, storedWebView) in webViews {
            if storedWebView === webView {
                DispatchQueue.main.async {
                    self.loadingStates[serviceId] = true
                }
                break
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Find the service ID for this webview
        for (serviceId, storedWebView) in webViews {
            if storedWebView === webView {
                DispatchQueue.main.async {
                    self.loadingStates[serviceId] = false
                    self.markForReloadIfOffline(serviceId)
                }
                break
            }
        }
    }
    
    // Handle provisional failures (common when offline at login)
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        for (serviceId, storedWebView) in webViews {
            if storedWebView === webView {
                DispatchQueue.main.async {
                    self.loadingStates[serviceId] = false
                    self.markForReloadIfOffline(serviceId)
                }
                break
            }
        }
    }
    
    // MARK: - Network monitoring & reload helpers
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let isNowOnline = (path.status == .satisfied)
            let wasOnline = self.hasNetworkConnectivity
            self.hasNetworkConnectivity = isNowOnline
            if isNowOnline && !wasOnline {
                let servicesToReload = self.pendingReloadServiceIds
                self.pendingReloadServiceIds.removeAll()
                DispatchQueue.main.async {
                    for serviceId in servicesToReload {
                        if let webView = self.webViews[serviceId], let url = webView.url ?? self.urlForServiceId(serviceId) {
                            var request = URLRequest(url: url)
                            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                            webView.reload()
                            webView.load(request)
                            self.loadingStates[serviceId] = true
                        }
                    }
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func markForReloadIfOffline(_ serviceId: String) {
        if !hasNetworkConnectivity {
            pendingReloadServiceIds.insert(serviceId)
        }
    }
    
    private func urlForServiceId(_ serviceId: String) -> URL? {
        if let service = aiServices.first(where: { $0.id.uuidString == serviceId }) {
            return service.url
        }
        return nil
    }
    
    // MARK: - WKUIDelegate Methods
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }
    
    // Add support for file uploads
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = parameters.allowsDirectories
        openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
        
        // Set file picker as active
        isFilePickerActive = true
        
        // Check file type filtering if available, but skip for older macOS versions
        if #available(macOS 11.0, *) {
            // Check if there's a way to get allowed file types
            // We can't use allowedContentTypes or allowsAllTypes directly
        }
        
        openPanel.begin { [weak self] (result) in
            // Reset file picker active state
            self?.isFilePickerActive = false
            
            if result == .OK {
                completionHandler(openPanel.urls)
            } else {
                completionHandler(nil)
            }
        }
    }
    
    // Function to manually trigger file upload for any service
    func triggerFileUpload(for service: AIService) {
        guard let webView = webViews[service.id.uuidString] else { return }
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.message = "Select files to upload"
        openPanel.prompt = "Upload"
        
        // Set file picker as active
        isFilePickerActive = true
        
        openPanel.begin { [weak self] (result) in
            guard let self = self else { return }
            
            // Reset file picker active state
            self.isFilePickerActive = false
            
            if result == .OK {
                // Using _ to explicitly ignore the value since we handle files through the browser's file input
                _ = openPanel.urls
                
                // Focus the webView first
                if let window = webView.window {
                    window.makeFirstResponder(webView)
                }
                
                // Find the appropriate file input in the webView and simulate a file selection
                // This script tries to find a file input and click it to trigger file selection UI
                // If the website has a custom file upload button, we need to click it
                let findAndClickFileInputScript = """
                (function() {
                    // Try to find visible file input
                    let fileInputs = Array.from(document.querySelectorAll('input[type="file"]'));
                    let visibleInput = fileInputs.find(input => {
                        let style = window.getComputedStyle(input);
                        return style.display !== 'none' && style.visibility !== 'hidden' && input.offsetWidth > 0;
                    });
                    
                    if (visibleInput) {
                        visibleInput.click();
                        return true;
                    }
                    
                    // Try to find file upload buttons
                    let uploadButtons = [];
                    
                    // ChatGPT
                    let chatgptButton = document.querySelector('button[aria-label="Attach files"]');
                    if (chatgptButton) {
                        uploadButtons.push(chatgptButton);
                    }
                    
                    // Claude
                    let claudeButton = document.querySelector('button[aria-label="Upload file"]');
                    if (claudeButton) {
                        uploadButtons.push(claudeButton);
                    }
                    
                    // Generic approach - look for buttons with upload-related text
                    const uploadKeywords = ['upload', 'file', 'attach', 'paperclip'];
                    document.querySelectorAll('button, a, div, span, i').forEach(element => {
                        const text = element.textContent?.toLowerCase() || '';
                        const ariaLabel = element.getAttribute('aria-label')?.toLowerCase() || '';
                        const classNames = element.className.toLowerCase();
                        
                        // Check if element or its children have upload-related info
                        const hasUploadKeyword = uploadKeywords.some(keyword => 
                            text.includes(keyword) || ariaLabel.includes(keyword) || classNames.includes(keyword)
                        );
                        
                        // Check for paperclip icons
                        const hasPaperclipIcon = element.querySelector('svg, img, i')?.className?.toLowerCase()?.includes('paperclip');
                        
                        if (hasUploadKeyword || hasPaperclipIcon) {
                            uploadButtons.push(element);
                        }
                    });
                    
                    if (uploadButtons.length > 0) {
                        uploadButtons[0].click();
                        return true;
                    }
                    
                    return false;
                })();
                """
                
                webView.evaluateJavaScript(findAndClickFileInputScript) { (result, error) in
                    if let success = result as? Bool, success {
                        print("Successfully clicked file input or upload button")
                    } else {
                        print("Could not find file input or upload button. Adding manual file upload support.")
                        
                        // If we couldn't find a proper file input, try to create one and simulate the file selection
                        let simulateFileUploadScript = """
                        (function() {
                            // Create a temporary file input if none found
                            const fileInput = document.createElement('input');
                            fileInput.type = 'file';
                            fileInput.multiple = true;
                            fileInput.style.display = 'none';
                            document.body.appendChild(fileInput);
                            
                            // Store references to important elements that we might need later
                            window.appleAITempFileInput = fileInput;
                            
                            // When files are selected, we'll try to handle them appropriately
                            fileInput.addEventListener('change', function() {
                                console.log('Files selected!', fileInput.files);
                                // We'll rely on the browser's file upload handling
                                
                                // Remove the element after use
                                setTimeout(() => {
                                    document.body.removeChild(fileInput);
                                    delete window.appleAITempFileInput;
                                }, 1000);
                            });
                            
                            // Trigger file selection dialog
                            fileInput.click();
                            return true;
                        })();
                        """
                        
                        webView.evaluateJavaScript(simulateFileUploadScript) { (result, error) in
                            if let error = error {
                                print("Error simulating file upload: \(error)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Function to inject service-specific JavaScript handlers
    private func injectServiceSpecificHandlers(_ webView: WKWebView, for service: AIService) {
        // All service-specific keyboard handlers have been removed
        // Keep only non-keyboard related functions that might be needed
    }
    
    // Function to inject JavaScript to handle microphone permissions
    private func injectMicrophonePermissionHandlers(_ webView: WKWebView) {
        // First, check current permission status
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let statusString = currentStatus == .authorized ? "granted" : "not granted"
        
        let script = """
        (function() {
            // Store permission status and keep track of attempts
            if (!window._microphonePermissionState) {
                window._microphonePermissionState = {
                    status: '\(statusString)',
                    requestAttempts: 0,
                    lastRequestTime: null,
                    buttonsWithListeners: new Set()
                };
            }
            
            // Store active audio streams and contexts to stop them later
            if (!window.activeAudioStreams) {
                window.activeAudioStreams = [];
            }
            
            // Override getUserMedia method to check our state before requesting
            const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
            navigator.mediaDevices.getUserMedia = async function(constraints) {
                console.log('getUserMedia called with constraints:', constraints);
                
                // If audio is requested, manage permission state
                if (constraints && constraints.audio) {
                    // Don't allow rapid repeated requests
                    const now = Date.now();
                    const minTimeBetweenRequests = 5000; // 5 seconds
                    
                    if (window._microphonePermissionState.lastRequestTime && 
                        (now - window._microphonePermissionState.lastRequestTime) < minTimeBetweenRequests) {
                        console.log('Throttling permission request to prevent repeated dialogs');
                        
                        // If we've already been granted permission, proceed
                        if (window._microphonePermissionState.status === 'granted') {
                            return await originalGetUserMedia.call(this, constraints);
                        }
                        
                        // Otherwise throw an appropriate error
                        const error = new DOMException('Permission request throttled to prevent multiple dialogs', 'NotAllowedError');
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'permissionThrottled',
                            error: error.toString()
                        });
                        throw error;
                    }
                    
                    // Update state
                    window._microphonePermissionState.lastRequestTime = now;
                    window._microphonePermissionState.requestAttempts++;
                    
                    console.log('Requesting microphone permission, attempt #' + window._microphonePermissionState.requestAttempts);
                    
                    try {
                        // This will trigger the permission dialog if needed
                        const stream = await originalGetUserMedia.call(this, constraints);
                        
                        // Store the stream for later cleanup
                        window.activeAudioStreams.push(stream);
                        
                        // Add a listener to detect when the stream ends
                        stream.addEventListener('inactive', function() {
                            console.log('Audio stream became inactive');
                            window.webkit.messageHandlers.mediaPermission.postMessage({
                                type: 'streamEnded',
                                reason: 'inactive'
                            });
                        });
                        
                        // Also add listeners to all tracks
                        stream.getTracks().forEach(track => {
                            track.addEventListener('ended', function() {
                                console.log('Audio track ended');
                                window.webkit.messageHandlers.mediaPermission.postMessage({
                                    type: 'streamEnded',
                                    reason: 'trackEnded'
                                });
                            });
                        });
                        
                        // Update our state on success
                        window._microphonePermissionState.status = 'granted';
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'permissionGranted',
                            source: 'getUserMedia'
                        });
                        
                        return stream;
                    } catch (error) {
                        console.error('Error getting microphone access:', error);
                        
                        // Update our state on failure
                        if (error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError') {
                            window._microphonePermissionState.status = 'denied';
                        }
                        
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'permissionError',
                            error: error.toString(),
                            errorName: error.name
                        });
                        
                        throw error;
                    }
                }
                
                // For other requests, use the original implementation
                return await originalGetUserMedia.call(this, constraints);
            };
            
            // Also hook into any voice recognition buttons or elements
            function setupVoiceButtonListeners() {
                // Look for typical voice input buttons across different AI platforms
                const voiceSelectors = [
                    'button[aria-label*="voice"]',
                    'button[aria-label*="microphone"]',
                    'button[aria-label*="speech"]',
                    'button[aria-label*="talk"]',
                    'button[title*="voice"]',
                    'button[title*="microphone"]',
                    'button[title*="speech"]',
                    'button[title*="talk"]',
                    'button[class*="voice"]',
                    'button[class*="microphone"]',
                    'button[class*="speech"]',
                    'button[class*="talk"]',
                    'button[id*="voice"]',
                    'button[id*="microphone"]',
                    'button[id*="speech"]',
                    'button[id*="talk"]',
                    'svg[aria-label*="voice"]',
                    'svg[aria-label*="microphone"]',
                    // ChatGPT specific
                    'button[data-testid="send-button-with-voice-control"]',
                    // Add more selectors as needed for specific platforms
                ];
                
                // Try to find any voice input buttons
                for (const selector of voiceSelectors) {
                    const elements = document.querySelectorAll(selector);
                    if (elements.length > 0) {
                        elements.forEach(element => {
                            // Only add listener if it doesn't already have one and we haven't tracked it
                            if (!element.dataset.micPermissionListener && 
                                !window._microphonePermissionState.buttonsWithListeners.has(element)) {
                                
                                element.dataset.micPermissionListener = 'true';
                                window._microphonePermissionState.buttonsWithListeners.add(element);
                                
                                // Add click listener for voice start
                                element.addEventListener('click', function(e) {
                                    console.log('Voice input element clicked');
                                    
                                    // Only request if not throttled
                                    const now = Date.now();
                                    const lastRequest = window._microphonePermissionState.lastRequestTime;
                                    
                                    if (!lastRequest || (now - lastRequest) > 5000) {
                                        console.log('Requesting microphone permissions from button click');
                                        window._microphonePermissionState.lastRequestTime = now;
                                        
                                        // Notify native app of button click
                                        window.webkit.messageHandlers.mediaPermission.postMessage({
                                            type: 'voiceButtonClicked',
                                            selector: selector
                                        });
                                        
                                        // Only request permission if not already denied
                                        if (window._microphonePermissionState.status !== 'denied') {
                                            navigator.mediaDevices.getUserMedia({ audio: true })
                                                .then(stream => {
                                                    console.log('Microphone access granted from button click');
                                                    // Store the stream for tracking
                                                    window.activeAudioStreams.push(stream);
                                                })
                                                .catch(err => console.error('Microphone access error from button click:', err));
                                        }
                                    }
                                });
                                
                                // Also try to find a stop button
                                let stopButton = null;
                                
                                // Look for stop button near this button (sibling, parent or child)
                                const stopSelectors = [
                                    'button[aria-label*="stop"]',
                                    'button[title*="stop"]',
                                    'button[aria-label*="cancel"]',
                                    'button[title*="cancel"]',
                                    'button.cancel',
                                    'button.stop'
                                ];
                                
                                // Look for a stop button in various places
                                for (const stopSelector of stopSelectors) {
                                    // Check siblings
                                    if (element.parentNode) {
                                        const siblings = element.parentNode.querySelectorAll(stopSelector);
                                        if (siblings.length > 0) {
                                            stopButton = siblings[0];
                                            break;
                                        }
                                    }
                                    
                                    // Check parent container
                                    const parentContainer = element.closest('.voice-container, .microphone-container');
                                    if (parentContainer) {
                                        const parentStops = parentContainer.querySelectorAll(stopSelector);
                                        if (parentStops.length > 0) {
                                            stopButton = parentStops[0];
                                            break;
                                        }
                                    }
                                }
                                
                                // If we found a stop button, add a listener
                                if (stopButton && !stopButton.dataset.micStopListener) {
                                    stopButton.dataset.micStopListener = 'true';
                                    
                                    stopButton.addEventListener('click', function() {
                                        console.log('Voice stop button clicked');
                                        
                                        // Notify the app that voice chat stopped
                                        window.webkit.messageHandlers.mediaPermission.postMessage({
                                            type: 'voiceChatStopped',
                                            reason: 'stopButton'
                                        });
                                        
                                        // Clean up any active streams
                                        if (window.activeAudioStreams) {
                                            window.activeAudioStreams.forEach(stream => {
                                                stream.getTracks().forEach(track => {
                                                    track.stop();
                                                });
                                            });
                                            window.activeAudioStreams = [];
                                        }
                                    });
                                }
                            }
                        });
                    }
                }
            }
            
            // Run immediately
            setupVoiceButtonListeners();
            
            // Also run when DOM changes to catch dynamically added elements
            const observer = new MutationObserver(setupVoiceButtonListeners);
            observer.observe(document.body, { 
                childList: true, 
                subtree: true 
            });
            
            console.log('Enhanced microphone permission handlers successfully injected');
        })();
        """
        
        webView.evaluateJavaScript(script) { (_, error) in
            if let error = error {
                print("Error injecting microphone permission handlers: \(error)")
            } else {
                print("Successfully injected microphone permission handlers")
            }
        }
    }
    
    // Add a helper method to fix permissions without triggering keychain
    private func injectPermissionFixer(_ webView: WKWebView?) {
        guard let webView = webView else { return }
        
        let script = """
        (function() {
            // Force permissions to work without additional prompts
            if (typeof navigator.mediaDevices !== 'undefined') {
                console.log('Fixing microphone permissions...');
                
                // Store original method
                const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
                
                // Replace with our version that avoids additional prompts
                navigator.mediaDevices.getUserMedia = async function(constraints) {
                    console.log('Fixed getUserMedia called:', constraints);
                    try {
                        return await originalGetUserMedia.call(this, constraints);
                    } catch (error) {
                        console.error('Permission error in fixed getUserMedia:', error);
                        
                        // Special handling for audio-only constraints to avoid repeated prompts
                        if (constraints && constraints.audio && !constraints.video) {
                            // If permission was previously granted at system level but WebKit is confused,
                            // return an empty audio track to satisfy the request
                            try {
                                console.log('Creating dummy audio track to bypass permission issues');
                                const ctx = new AudioContext();
                                const oscillator = ctx.createOscillator();
                                const dst = ctx.createMediaStreamDestination();
                                oscillator.connect(dst);
                                oscillator.start();
                                const dummyTrack = dst.stream.getAudioTracks()[0];
                                dummyTrack.enabled = false; // Mute it to prevent audio feedback
                                
                                // Create a MediaStream with our dummy track
                                const stream = new MediaStream([dummyTrack]);
                                return stream;
                            } catch (fallbackError) {
                                console.error('Failed to create dummy audio track:', fallbackError);
                                throw error; // Throw the original error
                            }
                        }
                        
                        throw error; // For other cases, throw the original error
                    }
                };
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { (_, error) in
            if let error = error {
                print("Error injecting permission fixer: \(error)")
            } else {
                print("Successfully injected permission fixer")
            }
        }
    }
    
    // Set the voice chat active state and communicate with WebViewCache
    func setVoiceChatActive(_ active: Bool) {
        // Update the voice chat active state
        isVoiceChatActive = active
        
        // If active, update the last activity time
        if active {
            lastVoiceActivityTime = Date()
        } else {
            // If setting to inactive, ensure we stop monitoring
            stopAllMicrophoneUse()
        }
    }
    
    // Function to stop all microphone use
    func stopAllMicrophoneUse() {
        // For each webview, execute script to stop all audio streams
        for (_, webView) in webViews {
            webView.evaluateJavaScript("""
            (function() {
                // Stop all audio tracks in MediaStream objects
                if (navigator.mediaDevices && navigator.mediaDevices._getUserMedia) {
                    navigator.mediaDevices._getUserMedia = navigator.mediaDevices.getUserMedia;
                }
                
                // Stop all active MediaStreams
                if (window.activeMicrophones) {
                    window.activeMicrophones.forEach(stream => {
                        if (stream && typeof stream.getTracks === 'function') {
                            stream.getTracks().forEach(track => {
                                if (track.kind === 'audio') {
                                    track.stop();
                                    console.log('Stopped audio track');
                                }
                            });
                        }
                    });
                    
                    // Clear the list
                    window.activeMicrophones = [];
                }
                
                // Reset voice chat UI elements if present
                const stopButtons = document.querySelectorAll('button[aria-label="Stop recording"], button[aria-label="Stop"]');
                stopButtons.forEach(button => button.click());
                
                return true;
            })();
            """) { _, _ in }
        }
    }
    
    // Inject script to stop all audio tracks and clean up resources
    private func injectAudioStopScript(_ webView: WKWebView) {
        let script = """
        (function() {
            console.log('Stopping all audio tracks and cleaning up audio resources');
            
            // Function to stop all tracks in a stream
            function stopAllTracks(stream) {
                if (stream && stream.getTracks) {
                    stream.getTracks().forEach(track => {
                        console.log('Stopping track:', track.kind);
                        try {
                            track.stop();
                            track.enabled = false;
                        } catch (e) {
                            console.error('Error stopping track:', e);
                        }
                    });
                }
            }
            
            // Stop any active AudioContext
            try {
                // Close all audio contexts - including any that might be created by the page
                const audioContexts = [];
                
                // Try to get audio contexts via our stored reference
                if (window.activeAudioContext) {
                    audioContexts.push(window.activeAudioContext);
                }
                
                // Also look for any global audio contexts
                if (typeof AudioContext !== 'undefined') {
                    // Try to find any other audio contexts that might be hidden in the page
                    Object.keys(window).forEach(key => {
                        try {
                            const obj = window[key];
                            if (obj instanceof AudioContext || 
                                (obj && obj.constructor && obj.constructor.name === 'AudioContext')) {
                                audioContexts.push(obj);
                            }
                        } catch (e) {}
                    });
                }
                
                // Close all found contexts
                audioContexts.forEach(ctx => {
                    try {
                        ctx.close();
                        console.log('Closed AudioContext');
                    } catch (e) {
                        console.error('Error closing AudioContext:', e);
                    }
                });
                
                window.activeAudioContext = null;
            } catch (e) {
                console.error('Error with audio contexts:', e);
            }
            
            // Stop any active oscillators
            if (window.activeOscillator) {
                try {
                    window.activeOscillator.stop();
                    console.log('Stopped active oscillator');
                } catch (e) {
                    console.error('Error stopping oscillator:', e);
                }
                window.activeOscillator = null;
            }
            
            // Clean up any stored audio streams
            if (window.activeAudioStreams && window.activeAudioStreams.length > 0) {
                window.activeAudioStreams.forEach(stream => {
                    stopAllTracks(stream);
                });
                window.activeAudioStreams = [];
                console.log('Cleaned up stored audio streams');
            }
            
            // Also check for any global or stored streams
            if (window.dummyAudioStream) {
                stopAllTracks(window.dummyAudioStream);
                window.dummyAudioStream = null;
                console.log('Cleaned up dummy audio stream');
            }
            
            // Extra cleanup - look for any MediaStream objects in the global scope
            try {
                Object.keys(window).forEach(key => {
                    try {
                        const obj = window[key];
                        if (obj instanceof MediaStream || 
                            (obj && obj.constructor && obj.constructor.name === 'MediaStream')) {
                            stopAllTracks(obj);
                            console.log('Stopped additional MediaStream:', key);
                        }
                    } catch (e) {}
                });
            } catch (e) {
                console.error('Error scanning for MediaStreams:', e);
            }
            
            // Extra: Try to reset getUserMedia to prevent automatic reconnection
            if (navigator.mediaDevices && navigator._mediaDevicesGetUserMedia) {
                navigator.mediaDevices.getUserMedia = function(constraints) {
                    console.log('Blocked getUserMedia after cleanup');
                    // Return a promise that never resolves to prevent automatic reconnection
                    return new Promise((resolve, reject) => {
                        // After a very short delay, restore the original function but reject the current call
                        setTimeout(() => {
                            navigator.mediaDevices.getUserMedia = navigator._mediaDevicesGetUserMedia;
                            reject(new DOMException('Microphone access temporarily disabled', 'NotAllowedError'));
                        }, 100);
                    });
                };
                
                // Reset after 500ms to allow normal function
                setTimeout(() => {
                    if (navigator._mediaDevicesGetUserMedia) {
                        navigator.mediaDevices.getUserMedia = navigator._mediaDevicesGetUserMedia;
                    }
                }, 500);
            }
            
            // Notify app that all audio has been stopped
            if (window.webkit && window.webkit.messageHandlers && 
                window.webkit.messageHandlers.mediaPermission) {
                try {
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'audioStopped'
                    });
                } catch (e) {
                    console.error('Error sending audio stopped message:', e);
                }
            }
            
            console.log('Audio resources cleanup complete');
            return true;
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error stopping audio resources: \(error)")
            } else {
                print("Successfully stopped audio resources")
            }
        }
    }
    
    private func stopAudioInCurrentWebView() {
        guard let webView = getCurrentWebView() else { return }
        
        print("Stopping audio in current WebView")
        
        // Simple script to stop all audio tracks without excessive monitoring
        let script = """
        (function() {
            console.log('Stopping microphone in web view');
            
            // Helper function to stop all tracks in a stream
            function stopTracks(stream) {
                if (stream && stream.getTracks) {
                    stream.getTracks().forEach(track => {
                        if (track.kind === 'audio') {
                            console.log('Stopping audio track');
                            track.stop();
                            track.enabled = false;
                        }
                    });
                }
            }
            
            try {
                // Stop any known active streams
                if (window.activeAudioStreams) {
                    window.activeAudioStreams.forEach(stream => stopTracks(stream));
                    window.activeAudioStreams = [];
                }
                
                // Clean up any AudioContext
                if (window.activeAudioContext) {
                    window.activeAudioContext.close();
                    window.activeAudioContext = null;
                }
                
                // Notify the system that audio is stopped
                if (window.webkit && window.webkit.messageHandlers && 
                    window.webkit.messageHandlers.mediaPermission) {
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'audioStopped'
                    });
                }
            } catch (e) {
                console.error('Error stopping audio:', e);
            }
            
            return true;
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error stopping audio: \(error)")
            } else {
                print("Successfully stopped audio in WebView")
            }
        }
    }
    
    private func getCurrentWebView() -> WKWebView? {
        guard let currentServiceID = currentServiceID else { return nil }
        return webViews[currentServiceID]
    }
    
    // Make sure to set it when accessing webviews
    private func updateCurrentServiceID(for service: AIService) {
        currentServiceID = service.id.uuidString
    }
    
    // Focus the current web view and attempt to give focus to any input fields
    func focusCurrentWebView(for service: AIService) {
        // Ensure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.focusCurrentWebView(for: service)
            }
            return
        }
        
        print("Attempting to focus web view for service: \(service.name)")
        
        // Get the main app window
        guard let window = NSApp.mainWindow else {
            print("Cannot focus webview: No main window found")
            return
        }
        
        // The container view that holds our views
        guard let containerView = window.contentView else {
            print("Cannot focus webview: No container view found")
            return
        }
        
        // Use multiple strategies to find and focus the webview and its input field
        
        // Variables to track what we find
        var foundWebView: WKWebView?
        var foundResponder = false
        
        // 1. First look for a KeyboardResponderView which is our specialized input handler
        for subview in containerView.subviews where !subview.isHidden {
            if let responderView = subview as? KeyboardResponderView {
                foundWebView = responderView.webView
                print("Found KeyboardResponderView with webView: \(foundWebView != nil)")
                
                // Make the responder view first responder
                window.makeFirstResponder(responderView)
                
                // Also directly make the webView first responder to be double-sure
                if let webView = foundWebView {
                    window.makeFirstResponder(webView)
                }
                
                foundResponder = true
                
                // Trigger our mouse entered detection to activate keyboard mode
                if let responder = responderView as? KeyboardResponderView {
                    // Manually trigger mouse entered to enable keyboard mode
                    let event = NSEvent.mouseEvent(
                        with: .mouseEntered,
                        location: NSPoint(x: responder.bounds.midX, y: responder.bounds.midY),
                        modifierFlags: [],
                        timestamp: 0,
                        windowNumber: window.windowNumber,
                        context: nil,
                        eventNumber: 0,
                        clickCount: 1,
                        pressure: 0
                    )
                    if let event = event {
                        responder.mouseEntered(with: event)
                    }
                }
                
                break
            }
        }
        
        // 2. If we couldn't find a responder view, try to find any WKWebView directly
        if !foundResponder || foundWebView == nil {
            // Recursive function to find WKWebView in the view hierarchy
            func findWebView(in view: NSView) -> WKWebView? {
                if let webView = view as? WKWebView {
                    return webView
                }
                
                for subview in view.subviews where !subview.isHidden {
                    if let webView = findWebView(in: subview) {
                        return webView
                    }
                }
                
                return nil
            }
            
            // Find the visible WKWebView
            foundWebView = findWebView(in: containerView)
            
            // Make it first responder if found
            if let webView = foundWebView {
                print("Found WKWebView directly")
                window.makeFirstResponder(webView)
            }
        }
        
        // 3. Use WebViewCache to get the webview directly as a final fallback
        if foundWebView == nil {
            foundWebView = WebViewCache.shared.getWebView(for: service)
            print("Getting webView from WebViewCache: \(foundWebView != nil)")
            if let webView = foundWebView {
                window.makeFirstResponder(webView)
            }
        }
        
        // 4. ULTRA-AGGRESSIVE INPUT FOCUSING: Use multiple approaches with different delays
        if let webView = foundWebView {
            print("Injecting focus scripts to find input field")
            
            // Try multiple focus techniques with varied timing
            // This is necessary because different services load at different speeds
            let delays: [TimeInterval] = [0.1, 0.3, 0.6, 1.0, 2.0, 3.0]
            
            for delay in delays {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    // Ensure webView is still valid before proceeding
                    guard webView.window != nil else { return }
                    
                    // Make sure webView is first responder
                    window.makeFirstResponder(webView)
                    
                    // Try multiple input focusing techniques
                    self.injectComprehensiveFocusScript(webView, attemptNumber: Int(delay * 10))
                }
            }
            
            // Also update our responder chain status
            if let view = foundWebView?.superview as? KeyboardResponderView {
                view.isLikelyInInputField = true
                view.keyboardModeActive = true
            }
        }
    }
    
    // Enhanced focus script that tries multiple techniques to focus inputs
    private func injectComprehensiveFocusScript(_ webView: WKWebView, attemptNumber: Int) {
        // This script combines multiple approaches to activate input fields:
        // 1. Direct focusing of known input elements
        // 2. Click simulation on input areas
        // 3. Specialized handling for common AI interfaces
        let script = """
        (function() {
            console.log('Focus attempt #\(attemptNumber)');
            
            // Helper to check if element is visible
            function isVisible(el) {
                if (!el) return false;
                const rect = el.getBoundingClientRect();
                return rect.width > 0 && rect.height > 0 &&
                       rect.top >= 0 && rect.left >= 0 &&
                       rect.top < window.innerHeight && rect.left < window.innerWidth;
            }
            
            // STRATEGY 1: Focus inputs directly
            function focusInputDirectly() {
                // Try all possible inputs in priority order
                const selectors = [
                    // ChatGPT specific
                    '[data-testid="chat-input-textbox"]', 
                    '[data-testid="text-area-input"]',
                    
                    // Claude specific
                    '.ProseMirror[contenteditable="true"]',
                    '.claude-input',
                    
                    // Standard inputs
                    'textarea', 
                    'input[type="text"]',
                    
                    // Generic AI inputs
                    '[contenteditable="true"]',
                    '.chat-input', 
                    '.message-input',
                    '[role="textbox"]'
                ];
                
                for (const selector of selectors) {
                    const elements = document.querySelectorAll(selector);
                    for (const el of elements) {
                        if (isVisible(el)) {
                            el.focus();
                            console.log('Focused element:', selector);
                            return true;
                        }
                    }
                }
                
                return false;
            }
            
            // STRATEGY 2: Click on inputs and areas that might reveal inputs
            function simulateClicks() {
                // Areas that might reveal inputs when clicked
                const clickSelectors = [
                    // Bottom of the page where inputs often are
                    '.chat-interface',
                    '.chat-input-container',
                    '.input-area',
                    
                    // ChatGPT specific
                    '.flex.w-full.items-center',
                    
                    // Claude specific
                    '.claude-input-container',
                    
                    // Last resort - anything that looks like it might be an input area
                    '.input',
                    '.textarea'
                ];
                
                for (const selector of clickSelectors) {
                    const elements = document.querySelectorAll(selector);
                    for (const el of elements) {
                        if (isVisible(el)) {
                            el.click();
                            console.log('Clicked on:', selector);
                            
                            // After clicking, try focusing inputs again
                            setTimeout(focusInputDirectly, 50);
                            return true;
                        }
                    }
                }
                
                return false;
            }
            
            // STRATEGY 3: Click at typical input locations
            function clickAtCommonInputLocations() {
                // Click at the bottom center where inputs usually are
                const clickSpots = [
                    { x: window.innerWidth / 2, y: window.innerHeight - 100 },
                    { x: window.innerWidth / 2, y: window.innerHeight - 150 },
                    { x: window.innerWidth / 2, y: window.innerHeight - 50 }
                ];
                
                for (const spot of clickSpots) {
                    // Create a simulated click
                    const clickEvent = new MouseEvent('click', {
                        view: window,
                        bubbles: true,
                        cancelable: true,
                        clientX: spot.x,
                        clientY: spot.y
                    });
                    
                    // Dispatch the click at the document's element at that position
                    const element = document.elementFromPoint(spot.x, spot.y);
                    if (element) {
                        element.dispatchEvent(clickEvent);
                        console.log('Clicked at position:', spot);
                        
                        // Try focusing again after click
                        setTimeout(focusInputDirectly, 50);
                        return true;
                    }
                }
                
                return false;
            }
            
            // Try all strategies in sequence
            let success = focusInputDirectly();
            
            if (!success) {
                success = simulateClicks();
            }
            
            if (!success) {
                success = clickAtCommonInputLocations();
            }
            
            // Last resort - try to click and focus body
            if (!success && document.body) {
                document.body.click();
                document.body.focus();
                
                // Try one more time after body interaction
                setTimeout(focusInputDirectly, 100);
                success = true;
            }
            
            // After any positive result, schedule one more focus attempt
            if (success) {
                setTimeout(focusInputDirectly, 200);
            }
            
            return { 
                success: success,
                attempt: \(attemptNumber),
                activeElement: document.activeElement ? document.activeElement.tagName : 'NONE'
            };
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Focus error (attempt \(attemptNumber)): \(error)")
            } else if let result = result as? [String: Any],
                      let success = result["success"] as? Bool,
                      let activeElement = result["activeElement"] as? String {
                print("Focus attempt \(attemptNumber): success=\(success), activeElement=\(activeElement)")
            }
        }
    }
    
    // Add a global method to force copy in any webview
    func forceCopySelection() {
        // Find the currently visible webview
        for (serviceId, webView) in webViews {
            if !webView.isHidden {
                // Try multiple copy approaches in sequence
                
                // 1. Native copy selector
                webView.performSelector(onMainThread: #selector(NSText.copy(_:)), with: nil, waitUntilDone: false)
                
                // 2. JavaScript execCommand approach
                webView.evaluateJavaScript("document.execCommand('copy', false, null);", completionHandler: nil)
                
                // 3. Modern clipboard API approach
                webView.evaluateJavaScript("""
                (function() {
                    const selection = window.getSelection();
                    if (selection && selection.toString()) {
                        try {
                            const text = selection.toString();
                            navigator.clipboard.writeText(text)
                                .then(() => console.log('Copy successful via clipboard API:', text))
                                .catch(err => console.error('Clipboard API copy failed:', err));
                            return true;
                        } catch(e) {
                            console.error('Error in force copy:', e);
                            return false;
                        }
                    } else {
                        // Try to get text from active element (input/textarea)
                        const activeElement = document.activeElement;
                        if (activeElement && 
                           (activeElement.tagName === 'INPUT' || 
                            activeElement.tagName === 'TEXTAREA')) {
                            
                            try {
                                const start = activeElement.selectionStart;
                                const end = activeElement.selectionEnd;
                                if (start !== end) {
                                    const text = activeElement.value.substring(start, end);
                                    navigator.clipboard.writeText(text)
                                        .then(() => console.log('Input field copy successful:', text))
                                        .catch(err => console.error('Input field copy failed:', err));
                                    return true;
                                }
                            } catch(e) {
                                console.error('Error copying from input field:', e);
                            }
                        }
                    }
                    return false;
                })();
                """, completionHandler: { (result, error) in
                    if let error = error {
                        print("Force copy JavaScript error: \(error)")
                    } else if let success = result as? Bool {
                        print("Force copy result: \(success ? "success" : "no selection found")")
                    }
                })
                
                // Only need to do this for the visible webview
                break
            }
        }
    }
    
    // Enhanced function to help focus the web view once without multiple attempts
    private func ensureWebViewFocus(delay: TimeInterval = 0.0) {
        // Just a single attempt with minimal delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.focusWebView()
        }
    }
    
    // Function to help focus the web view - try to find any WKWebView
    private func focusWebView() {
        guard let window = NSApplication.shared.keyWindow else { return }
        
        // Find any WKWebView in the view hierarchy and make it first responder
        func findAndFocusWebView(in view: NSView) -> Bool {
            // First check if view is a WKWebView (best case)
            if NSStringFromClass(type(of: view)).contains("WKWebView") {
                print("FOCUS: Found WKWebView directly, focusing it")
                window.makeFirstResponder(view)
                return true
            }
            
            // Check if this view is a KeyboardResponderView (second best)
            if NSStringFromClass(type(of: view)).contains("KeyboardResponderView") {
                print("FOCUS: Found KeyboardResponderView, focusing it")
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
}

// A coordinator class to handle WKWebView callbacks
// Legacy coordinator kept for compatibility
class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    var parent: AIWebView
    
    init(_ parent: AIWebView) {
        self.parent = parent
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        parent.isLoading = false
        
        // Make the webView the first responder when navigation completes
        DispatchQueue.main.async {
            if let window = webView.window {
                window.makeFirstResponder(webView)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        parent.isLoading = true
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        parent.isLoading = false
    }
    
    // WKUIDelegate methods for handling UI interactions
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }
}

// Key event handler view to intercept keyboard events
class KeyboardResponderView: NSView {
    weak var webView: WKWebView?
    
    // Add a timer to repeatedly attempt focus until successful
    private var focusAttemptTimer: Timer?
    // Track if we've received focus yet
    private var hasFocus = false
    // Track if keyboard mode is active - make internal instead of private
    internal var keyboardModeActive = false
    // Track if we're likely in an input field - make internal instead of private
    internal var isLikelyInInputField = false
    
    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        
        // Start focus attempt timer
        startFocusAttemptTimer()
        
        // Install the keyboard event trap, but with better input detection
        setupKeyboardTrap()
        
        // Start recurring checks for input field status
        startInputFieldDetectionTimer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Create a keyboard event trap that's smarter about input fields
    private func setupKeyboardTrap() {
        // Create a tracking area that covers the entire view
        // This ensures we get mouse events to detect when cursor enters/exits
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect, .enabledDuringMouseDrag],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    // Detect when mouse enters our view to activate keyboard mode
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        keyboardModeActive = true
        print("Keyboard mode activated - inside webview area")
        
        // Check for input field immediately when mouse enters
        checkForInputFieldStatus()
    }
    
    // Detect when mouse exits our view to deactivate keyboard mode
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        keyboardModeActive = false
        isLikelyInInputField = false
        print("Keyboard mode deactivated - outside webview area")
    }
    
    // Periodically check if we're in an input field
    private func startInputFieldDetectionTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.keyboardModeActive else { return }
            
            // Check if we're likely in an input field
            self.checkForInputFieldStatus()
        }
    }
    
    // Check if we're in an input field by asking the webView
    private func checkForInputFieldStatus() {
        guard let webView = webView else { return }
        
        // Use JavaScript to check if cursor is in an input field
        let script = """
        (function() {
            // Check if any input element is focused
            const activeElement = document.activeElement;
            
            // Detect standard input elements
            const isInput = activeElement.tagName === 'INPUT' || 
                          activeElement.tagName === 'TEXTAREA' || 
                          activeElement.hasAttribute('contenteditable');
            
            // For ChatGPT special case
            const isChatGPTInput = document.querySelector('[data-testid="chat-input-textbox"]') === activeElement;
            
            // For Claude special case
            const isClaudeInput = activeElement.classList.contains('ProseMirror') || 
                                activeElement.classList.contains('claude-input');
            
            // Generic AI assistants may use div with contenteditable
            const isGenericAIInput = activeElement.hasAttribute('contenteditable') || 
                                  (activeElement.role === 'textbox');
            
            return {
                activeTagName: activeElement.tagName,
                isInputElement: isInput || isChatGPTInput || isClaudeInput || isGenericAIInput,
                hasFocus: document.hasFocus()
            };
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] (result, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error checking input status: \(error)")
                // Assume we're not in an input field on error
                self.isLikelyInInputField = false
                return
            }
            
            if let result = result as? [String: Any],
               let isInputElement = result["isInputElement"] as? Bool,
               let hasFocus = result["hasFocus"] as? Bool {
                
                let wasInInputField = self.isLikelyInInputField
                self.isLikelyInInputField = isInputElement && hasFocus
                
                // Debug info
                if let activeTagName = result["activeTagName"] as? String {
                    print("Active element: \(activeTagName), IsInput: \(isInputElement), HasFocus: \(hasFocus)")
                }
                
                if wasInInputField != self.isLikelyInInputField {
                    if self.isLikelyInInputField {
                        print("✅ Input field detected - enabling typing")
                    } else {
                        print("❌ No input field detected - blocking keypresses")
                    }
                }
            }
        }
    }
    
    // Start a timer that repeatedly tries to grab focus
    private func startFocusAttemptTimer() {
        // Cancel any existing timer
        focusAttemptTimer?.invalidate()
        
        // Create a new timer that attempts to grab focus every 100ms
        focusAttemptTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, !self.hasFocus else {
                timer.invalidate()
                return
            }
            
            // Attempt to become first responder
            if let window = self.window {
                window.makeFirstResponder(self)
                
                // If we have focus, attempt to push it to the webView if appropriate
                if window.firstResponder === self {
                    self.hasFocus = true
                    
                    // Also try to focus the webView
                    if let webView = self.webView, webView.isDescendant(of: self) {
                        window.makeFirstResponder(webView)
                        
                        // Inject JavaScript to focus the input field
                        self.injectFocusScript(webView)
                    }
                    
                    // Stop the timer after we got focus
                    timer.invalidate()
                }
            }
        }
    }
    
    // Inject JavaScript to focus the first input field in the webView
    private func injectFocusScript(_ webView: WKWebView) {
        let script = """
        (function() {
            // Try to focus any input field
            function attemptFocus() {
                // First try to find a text input that's visible
                const inputs = document.querySelectorAll('input[type="text"], textarea, [contenteditable="true"]');
                for (let i = 0; i < inputs.length; i++) {
                    const input = inputs[i];
                    const rect = input.getBoundingClientRect();
                    // Check if element is visible and in viewport
                    if (rect.width > 0 && rect.height > 0 && 
                        rect.top >= 0 && rect.left >= 0 && 
                        rect.bottom <= window.innerHeight && rect.right <= window.innerWidth) {
                        input.focus();
                        console.log('Focused input element');
                        return true;
                    }
                }
                
                // If no input found, try to find the main input area for AI assistants
                const aiInputs = document.querySelectorAll(
                    // ChatGPT
                    'div[data-testid="chat-input-textbox"], ' +
                    // Claude
                    'div.ProseMirror[contenteditable="true"], ' +
                    // Generic
                    'div.chat-input, div.message-input'
                );
                
                for (let i = 0; i < aiInputs.length; i++) {
                    const input = aiInputs[i];
                    input.focus();
                    console.log('Focused AI input element');
                    return true;
                }
                
                // If all else fails, try to click on the document body
                if (document.body) {
                    document.body.click();
                    console.log('Clicked document body');
                    return true;
                }
                
                return false;
            }
            
            // Try immediately
            let success = attemptFocus();
            
            // If not successful, try again a few times with delays
            if (!success) {
                setTimeout(attemptFocus, 200);
                setTimeout(attemptFocus, 500);
                setTimeout(attemptFocus, 1000);
                setTimeout(attemptFocus, 2000);
            }
            
            return success;
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error injecting focus script: \(error)")
            } else if let success = result as? Bool, success {
                print("Successfully focused input element in webView")
                
                // If focus successful, update our status
                self.isLikelyInInputField = true
            } else {
                print("Could not find input element to focus")
                
                // If no input element found, try a more aggressive approach that uses click events
                self.injectAggressiveFocusScript(webView)
            }
        }
    }
    
    // More aggressive focus script that tries to simulate clicks on the input area
    private func injectAggressiveFocusScript(_ webView: WKWebView) {
        let script = """
        (function() {
            // Find any chat box or AI input area and simulate clicks
            function clickChatArea() {
                // First try known chat UI containers
                const chatContainers = document.querySelectorAll(
                    '.chat-container, .conversation-container, .message-list, .chat-view, ' +
                    '.model-response-view, .chat-interface, [data-testid="conversation-turn-"]'
                );
                
                for (const container of chatContainers) {
                    if (container.getBoundingClientRect().height > 0) {
                        // Click in the middle of the container
                        const rect = container.getBoundingClientRect();
                        const x = rect.left + rect.width / 2;
                        const y = rect.bottom - 50; // Near the bottom where inputs usually are
                        
                        console.log('Clicking chat container at', x, y);
                        
                        // Create and dispatch mouse events
                        ['mousedown', 'mouseup', 'click'].forEach(type => {
                            const event = new MouseEvent(type, {
                                bubbles: true,
                                cancelable: true,
                                view: window,
                                clientX: x,
                                clientY: y
                            });
                            container.dispatchEvent(event);
                        });
                        return true;
                    }
                }
                
                // If that didn't work, try clicking at the bottom of the window where inputs usually are
                const x = window.innerWidth / 2;
                const y = window.innerHeight - 100;
                
                console.log('Clicking bottom of window at', x, y);
                
                // Create a temporary clickable element
                const clickTarget = document.createElement('div');
                clickTarget.style.position = 'fixed';
                clickTarget.style.left = '0';
                clickTarget.style.right = '0';
                clickTarget.style.bottom = '0';
                clickTarget.style.height = '200px';
                clickTarget.style.zIndex = '9999';
                document.body.appendChild(clickTarget);
                
                // Click it
                clickTarget.click();
                
                // Clean up
                setTimeout(() => {
                    document.body.removeChild(clickTarget);
                }, 100);
                
                return true;
            }
            
            // Try clicking
            return clickChatArea();
        })();
        """
        
        webView.evaluateJavaScript(script) { (_, _) in
            // After aggressive focus attempt, try looking for input fields again after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.injectFocusScript(webView)
            }
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        // When added to a window, try to grab focus
        if let window = self.window {
            startFocusAttemptTimer()
            window.makeFirstResponder(self)
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        // When we become first responder, update our flag
        hasFocus = true
        
        // Stop the timer since we now have focus
        focusAttemptTimer?.invalidate()
        
        // Also try to pass focus to the webView
        if let webView = self.webView, webView.isDescendant(of: self) {
            DispatchQueue.main.async {
                self.window?.makeFirstResponder(webView)
                
                // Inject focus script
                self.injectFocusScript(webView)
            }
        }
        
        return super.becomeFirstResponder()
    }
    
    // IMPROVED: Enhanced key handling to prevent app from quitting unexpectedly
    override func keyDown(with event: NSEvent) {
        print("WEBVIEW KEY: Key down \(event.keyCode)")
        
        // CRITICAL: ALWAYS intercept ALL keys, especially Enter and Escape
        // This prevents the app from quitting unexpectedly
        
        // CASE 1: Special handling for Enter and ESC keys
        if event.keyCode == 0x24 || event.keyCode == 0x35 {  // Enter or ESC
            print("WEBVIEW: Intercepting Enter/ESC key to prevent app quit")
            
            // Only forward Enter key to webView if in a proper input field
            if event.keyCode == 0x24 && keyboardModeActive && isLikelyInInputField {
                if let webView = self.webView, webView.isDescendant(of: self) {
                    print("WEBVIEW: Safely forwarding Enter key to input field")
                    webView.keyDown(with: event)
                }
            }
            
            // Always consume the event
            return
        }
        
        // CASE 2: ALWAYS allow Command+E to toggle window
        if event.modifierFlags.contains(.command) && 
           event.keyCode == 0x0E && 
           event.charactersIgnoringModifiers == "e" {
            // This is our app's main shortcut - let it through to top level
            NSApp.sendAction(Selector(("togglePopupWindow")), to: nil, from: nil)
            print("WEBVIEW: Allowed Command+E toggle")
            return
        }
        
        // CASE 3: Block Command+Q and Command+W to prevent accidental closing
        if event.modifierFlags.contains(.command) {
            if event.keyCode == 0x0C && event.charactersIgnoringModifiers == "q" {
                print("WEBVIEW: Blocking Command+Q")
                return // Block quit
            }
            
            if event.keyCode == 0x0D && event.charactersIgnoringModifiers == "w" {
                print("WEBVIEW: Blocking Command+W")
                return // Block close
            }
            
            // ENHANCED: Force copy functionality (Command+C)
            if event.keyCode == 0x08 && event.charactersIgnoringModifiers == "c" {
                print("WEBVIEW: Handling Command+C (Copy)")
                if let webView = self.webView {
                    // Try direct NSText.copy selector
                    webView.performSelector(onMainThread: #selector(NSText.copy(_:)), with: nil, waitUntilDone: false)
                    
                    // Also try JavaScript document.execCommand as backup
                    webView.evaluateJavaScript("document.execCommand('copy', false, null);", completionHandler: { (result, error) in
                        if let error = error {
                            print("WEBVIEW: JavaScript copy command error: \(error)")
                        } else {
                            print("WEBVIEW: JavaScript copy command executed")
                        }
                    })
                    
                    // Try one more approach with the current selection
                    webView.evaluateJavaScript("""
                    (function() {
                        const selection = window.getSelection();
                        if (selection && selection.toString()) {
                            // We have text selected, try to copy it
                            try {
                                const textToCopy = selection.toString();
                                navigator.clipboard.writeText(textToCopy)
                                    .then(() => console.log('Copied text using clipboard API'))
                                    .catch(err => console.error('Failed to copy: ', err));
                                return true;
                            } catch(e) {
                                console.error('Copy failed:', e);
                                return false;
                            }
                        }
                        return false;
                    })();
                    """, completionHandler: { (result, error) in
                        if let success = result as? Bool, success {
                            print("WEBVIEW: Successfully copied selection using clipboard API")
                        }
                    })
                }
                return
            }
        }
        
        // CASE 4: When in keyboard mode and in a proper input field, allow typing
        if keyboardModeActive {
            // For standard editing shortcuts in keyboard mode
            if event.modifierFlags.contains(.command) {
                // Only standard editing shortcuts
                let editingShortcuts: [UInt16: String] = [
                    0x00: "selectAll:", // A
                    // 0x08: "copy:", - Handled separately above for better reliability
                    0x09: "paste:",     // V
                    0x07: "cut:",       // X
                    0x0C: "undo:",      // Z
                    0x0D: "redo:"       // Y
                ]
                
                if let selector = editingShortcuts[event.keyCode], 
                   let webView = self.webView {
                    print("WEBVIEW: Allowing editing shortcut \(selector)")
                    webView.performSelector(onMainThread: Selector(selector), with: nil, waitUntilDone: false)
                    return
                }
                
                // Block all other command shortcuts
                print("WEBVIEW: Blocking command shortcut \(event.keyCode)")
                return
            }
            
            // Forward typing keys to webView when in keyboard mode
            // IMPROVED: Only forward keys when we're likely in an input field
            if let webView = self.webView, webView.isDescendant(of: self) {
                if isLikelyInInputField {
                    print("WEBVIEW: Forwarding typing key \(event.keyCode) to input field")
                    webView.keyDown(with: event)
                } else {
                    print("WEBVIEW: Consuming key \(event.keyCode) - not in input field")
                    // Just consume the event without forwarding
                }
                return
            }
        }
        
        // Block all other key events
        print("WEBVIEW: Blocking key \(event.keyCode)")
    }
    
    // IMPROVED: Enhanced key equivalent handling to prevent app quitting
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        print("WEBVIEW: performKeyEquivalent \(event.keyCode)")
        
        // CRITICAL: ALWAYS handle all key equivalents involving ESC and Enter keys
        if event.keyCode == 0x35 || event.keyCode == 0x24 {
            print("WEBVIEW: Intercepting ESC/Enter key from performKeyEquivalent")
            // We're pretending we handled it to prevent it from bubbling up
            return true
        }
        
        // ALLOW CASE: Always allow Command+E to toggle window
        if event.modifierFlags.contains(.command) && 
           event.keyCode == 0x0E && 
           event.charactersIgnoringModifiers == "e" {
            // Send action to toggle window
            NSApp.sendAction(Selector(("togglePopupWindow")), to: nil, from: nil)
            print("WEBVIEW: Allowed Command+E toggle")
            return true
        }
        
        // ENHANCED: Special handling for Command+C (Copy)
        if event.modifierFlags.contains(.command) && 
           event.keyCode == 0x08 && 
           event.charactersIgnoringModifiers == "c" {
            print("WEBVIEW: Handling Command+C from performKeyEquivalent")
            
            if let webView = self.webView {
                // Try multiple copy approaches
                // 1. Direct selector
                webView.performSelector(onMainThread: #selector(NSText.copy(_:)), with: nil, waitUntilDone: false)
                
                // 2. JavaScript for DOM-based copy
                webView.evaluateJavaScript("document.execCommand('copy', false, null);", completionHandler: nil)
                
                // 3. More advanced clipboard API approach
                webView.evaluateJavaScript("""
                (function() {
                    const selection = window.getSelection();
                    if (selection && selection.toString()) {
                        try {
                            navigator.clipboard.writeText(selection.toString())
                                .then(() => console.log('Text copied using clipboard API'))
                                .catch(err => console.error('Copy failed:', err));
                        } catch(e) {
                            console.error('Copy failed:', e);
                        }
                    }
                })();
                """, completionHandler: nil)
            }
            
            // Let the event pass through to standard system handling as well
            return false
        }
        
        // BLOCK CASE: Command+Q and Command+W to prevent app quitting/closing
        if event.modifierFlags.contains(.command) {
            if event.keyCode == 0x0C || event.keyCode == 0x0D {
                print("WEBVIEW: Blocking quit/close keyboard shortcut")
                return true // Claim we handled it to prevent default action
            }
        }
        
        // IMPROVED: For all key equivalents when in an input field
        if keyboardModeActive && isLikelyInInputField {
            // Standard shortcuts for editing should be passed to WebView
            let editingShortcuts: [UInt16: Bool] = [
                    0x00: true, // A (select all)
                    0x08: true, // C (copy)
                    0x09: true, // V (paste)
                    0x07: true, // X (cut)
                    0x0C: true, // Z (undo)
                    0x0D: true  // Y (redo)
            ]
            
            if event.modifierFlags.contains(.command), editingShortcuts[event.keyCode] == true {
                return false // Let standard editing shortcuts pass through
            }
        }
        
        // Block all other key equivalents to be safe
        return true
    }
    
    // Also simplify key up handling - always catch it to match keyDown behavior
    override func keyUp(with event: NSEvent) {
        // IMPROVED: Similar handling to keyDown for consistency
        if event.keyCode == 0x35 || event.keyCode == 0x24 {
            print("WEBVIEW: Intercepting ESC/Enter key up")
            // Forward Enter keyUp to webView only if in input field
            if event.keyCode == 0x24 && keyboardModeActive && isLikelyInInputField {
                if let webView = self.webView, webView.isDescendant(of: self) {
                    webView.keyUp(with: event)
                }
            }
            return
        }
        
        // Forward keyUp to webView only when in keyboard mode and input field
        if keyboardModeActive && isLikelyInInputField, 
           let webView = self.webView, webView.isDescendant(of: self) {
            webView.keyUp(with: event)
        }
    }
    
    // Handle modifier key events with same approach
    override func flagsChanged(with event: NSEvent) {
        // Forward modifier keys only when in input field
        if keyboardModeActive && isLikelyInInputField, 
           let webView = self.webView, webView.isDescendant(of: self) {
            webView.flagsChanged(with: event)
        }
    }
    
    // Override to make sure we get key events even in unusual circumstances
    override var needsPanelToBecomeKey: Bool {
        return true
    }
    
    override func resignFirstResponder() -> Bool {
        // Attempt to keep focus when possible
        if keyboardModeActive {
            // Try to retain focus in keyboard mode
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let window = self.window {
                    window.makeFirstResponder(self.webView)
                }
            }
        }
        return super.resignFirstResponder()
    }
}

// New persistent WebView that uses the cache
struct PersistentWebView: NSViewRepresentable {
    let service: AIService
    @Binding var isLoading: Bool
    
    func makeNSView(context: Context) -> NSView {
        // Create a container view
        let containerView = NSView(frame: .zero)
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        
        // Create all webviews for all services and add them to the container
        // But only show the selected one
        for cachedService in aiServices {
            let webView = WebViewCache.shared.getWebView(for: cachedService)
            webView.frame = containerView.bounds
            webView.autoresizingMask = [.width, .height]
            
            // Create a keyboard responder view for this web view
            let responderView = KeyboardResponderView(webView: webView)
            responderView.frame = containerView.bounds
            responderView.autoresizingMask = [.width, .height]
            
            // Add the responder view to the container
            containerView.addSubview(responderView)
            
            // Add the webview to the responder view
            responderView.addSubview(webView)
            
        }
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update loading status
        isLoading = WebViewCache.shared.loadingStates[service.id.uuidString] ?? true
        
        // Show only the selected webview, hide all others
        var didUpdateVisibility = false
        for subview in nsView.subviews {
            if let responderView = subview as? KeyboardResponderView {
                // Find which service this responder's webview belongs to
                if let webView = responderView.webView {
                    for cachedService in aiServices {
                        if webView === WebViewCache.shared.getWebView(for: cachedService) {
                            // Check if we're changing visibility
                            let shouldBeVisible = cachedService.id == service.id
                            if responderView.isHidden == shouldBeVisible {
                                didUpdateVisibility = true
                            }
                            // Set visibility based on whether this is the selected service
                            responderView.isHidden = !shouldBeVisible
                        }
                    }
                }
            }
        }
        
        // Focus the current webview, with added delays if we just changed visibility
        if didUpdateVisibility {
            // Multiple attempts with increasing delays to handle race conditions
            let delays: [TimeInterval] = [0.1, 0.3, 0.6, 1.0]
            for delay in delays {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    focusCurrentWebView(in: nsView)
                }
            }
        } else {
            // Single attempt if we didn't change visibility
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusCurrentWebView(in: nsView)
            }
        }
    }
    
    private func focusCurrentWebView(in containerView: NSView) {
        // Get the window containing the container view
        guard let window = containerView.window else { return }
        
        // Attempt multiple approaches to ensure focus reaches the right place
        
        // 1. First try to find and focus the visible KeyboardResponderView
        var foundResponder = false
        var foundWebView: WKWebView? = nil
        
        for subview in containerView.subviews where !subview.isHidden {
            if let responderView = subview as? KeyboardResponderView {
                // Make the responder view the first responder
                window.makeFirstResponder(responderView)
                
                // Also try to focus the webView inside it
                if let webView = responderView.webView {
                    // Store reference to the found webView for later
                    foundWebView = webView
                    
                    // Try to directly focus the webView
                    window.makeFirstResponder(webView)
                }
                
                foundResponder = true
                break
            }
        }
        
        // 2. If we couldn't find a responder view, try to find the visible WKWebView directly
        if !foundResponder || foundWebView == nil {
            // Recursive function to find WKWebView in the view hierarchy
            func findWebView(in view: NSView) -> WKWebView? {
                if let webView = view as? WKWebView {
                    return webView
                }
                
                for subview in view.subviews where !subview.isHidden {
                    if let webView = findWebView(in: subview) {
                        return webView
                    }
                }
                
                return nil
            }
            
            // Find the visible WKWebView
            foundWebView = findWebView(in: containerView)
            
            // Make it first responder if found
            if let webView = foundWebView {
                window.makeFirstResponder(webView)
            }
        }
        
        // 3. Use WebViewCache to get the webview directly as a final fallback
        if foundWebView == nil {
            foundWebView = WebViewCache.shared.getWebView(for: service)
            window.makeFirstResponder(foundWebView)
        }
        
        // 4. Inject focus script to ensure input field gets focus
        // We attempt this multiple times with increasing delays to handle different page load times
        if let webView = foundWebView {
            // Schedule multiple attempts with increasing delays
            let delays: [TimeInterval] = [0.1, 0.3, 0.6, 1.0, 2.0]
            
            for delay in delays {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    // Make sure webView is first responder before injecting JavaScript
            window.makeFirstResponder(webView)
            
                    // Inject JavaScript to find and focus an input field
                let focusScript = """
                (function() {
                        // Find and focus any input in the following priority:
                        // 1. Visible text inputs/textareas
                        // 2. AI assistant specific inputs
                        // 3. Any contenteditable element
                        // 4. Document body as a fallback
                        
                        // Helper to check if element is visible
                        function isVisible(el) {
                            if (!el) return false;
                            const rect = el.getBoundingClientRect();
                            return rect.width > 0 && rect.height > 0 &&
                                   rect.top >= 0 && rect.left >= 0 &&
                                   rect.top < window.innerHeight && rect.left < window.innerWidth;
                        }
                        
                        // 1. Try visible text inputs first
                        const inputs = document.querySelectorAll('input[type="text"], textarea');
                        for (const input of inputs) {
                            if (isVisible(input)) {
                                input.focus();
                                console.log('Focused text input');
                        return true;
                            }
                        }
                        
                        // 2. Try AI assistant specific inputs
                        // ChatGPT
                        let chatgptInput = document.querySelector('[data-testid="chat-input-textbox"], [data-testid="text-area-input"]');
                        if (chatgptInput && isVisible(chatgptInput)) {
                            chatgptInput.focus();
                            chatgptInput.click();
                            console.log('Focused ChatGPT input');
                            return true;
                        }
                        
                        // Claude
                        let claudeInput = document.querySelector('.ProseMirror[contenteditable="true"], .claude-input');
                        if (claudeInput && isVisible(claudeInput)) {
                            claudeInput.focus();
                            claudeInput.click();
                            console.log('Focused Claude input');
                            return true;
                        }
                        
                        // Generic AI inputs
                        let aiInputs = document.querySelectorAll('[contenteditable="true"], .chat-input, .message-input');
                        for (const input of aiInputs) {
                            if (isVisible(input)) {
                                input.focus();
                                input.click();
                                console.log('Focused generic AI input');
                                return true;
                            }
                        }
                        
                        // 3. Any contenteditable as a fallback
                        let editables = document.querySelectorAll('[contenteditable]');
                        for (const editable of editables) {
                            if (isVisible(editable)) {
                                editable.focus();
                                editable.click();
                                console.log('Focused contenteditable');
                                return true;
                            }
                        }
                        
                        // 4. Final fallback - click the document body
                    if (document.body) {
                        document.body.click();
                            console.log('Clicked document body');
                            
                            // In some AI UIs, clicking body may reveal the input - check again
                            setTimeout(() => {
                                const inputs = document.querySelectorAll('input[type="text"], textarea, [contenteditable="true"]');
                                for (const input of inputs) {
                                    if (isVisible(input)) {
                                        input.focus();
                                        return;
                                    }
                                }
                            }, 100);
                            
                        return true;
                    }
                    
                    return false;
                })();
                """
                
                webView.evaluateJavaScript(focusScript) { (result, error) in
                    if let error = error {
                            print("Error focusing input at delay \(delay): \(error)")
                        } else if let success = result as? Bool, success {
                            print("Successfully focused input at delay \(delay)")
                        }
                    }
                }
            }
        }
    }
}

// Original AIWebView (kept for backwards compatibility)
struct AIWebView: NSViewRepresentable {
    let url: URL
    let service: AIService
    @Binding var isLoading: Bool
    
    // For SwiftUI previews
    init(url: URL, service: AIService) {
        self.url = url
        self.service = service
        self._isLoading = .constant(true)
    }
    
    // For actual use
    init(url: URL, service: AIService, isLoading: Binding<Bool>) {
        self.url = url
        self.service = service
        self._isLoading = isLoading
    }
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        // Use the WebViewCache to get the webview for this service
        return WebViewCache.shared.getWebView(for: service)
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Update loading status
        isLoading = WebViewCache.shared.loadingStates[service.id.uuidString] ?? true
        
        // Ensure the webView is the first responder when it becomes visible
        DispatchQueue.main.async {
            if let window = nsView.window, !nsView.isHidden {
                window.makeFirstResponder(nsView)
            }
        }
    }
}

// Add a SwiftUI representable NSViewController to ensure proper focus handling
class WebViewHostingController: NSViewController {
    var webView: WKWebView
    
    init(webView: WKWebView) {
        self.webView = webView
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = webView
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Ensure the webView becomes first responder when the view appears
        DispatchQueue.main.async { [weak self] in
            if let window = self?.view.window {
                window.makeFirstResponder(self?.webView)
            }
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
}

struct WebViewWindow: View {
    let service: AIService
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Colored divider for visual separation - just keep this
            Rectangle()
                .frame(height: 2)
                .foregroundColor(service.color)
            
            // WebView content area
            PersistentWebView(service: service, isLoading: $isLoading)
                .onChange(of: service) { newService in
                    // When service changes, ensure the loading status is updated
                    isLoading = WebViewCache.shared.loadingStates[newService.id.uuidString] ?? true
                }
                .onAppear {
                    // Short delay to ensure view is fully loaded before attempting to set focus
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let window = NSApplication.shared.keyWindow {
                            // Attempt to find and focus the webView for this service
                            let currentWebView = WebViewCache.shared.getWebView(for: service)
                            window.makeFirstResponder(currentWebView)
                        }
                    }
                }
        }
    }
} 
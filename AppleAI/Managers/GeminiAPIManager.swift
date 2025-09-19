//
//  GeminiAPIManager.swift
//  AppleAI
//
//  Created for AppleAI Project
//

import Foundation
import SwiftUI
import Combine

// Make sure to include AIService model
import os.log

class GeminiAPIManager: ObservableObject {
    static let shared = GeminiAPIManager()
    
    @Published var apiKey: String = "" {
        didSet {
            saveApiKey()
            generateGeminiHTML()
            // Notify observers that the API key has changed with its status (empty or not)
            NotificationCenter.default.post(name: NSNotification.Name("GeminiAPIKeyChanged"), object: apiKey.isEmpty)
            // Force reload of the WebView when API key changes
            reloadWebView()
        }
    }
    
    @Published var chatgptApiKey: String = "" {
        didSet {
            saveChatGPTApiKey()
            generateGeminiHTML()
            NotificationCenter.default.post(name: NSNotification.Name("GeminiAPIKeyChanged"), object: (apiKey.isEmpty && chatgptApiKey.isEmpty))
            reloadWebView()
        }
    }
    
    private let htmlDirectoryURL: URL
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Get the documents directory
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        htmlDirectoryURL = documentsDirectory.appendingPathComponent("GeminiChat", isDirectory: true)
        
        // Create the directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: htmlDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating Gemini directory: \(error)")
        }
        
        // Load the API keys from UserDefaults
        loadApiKey()
        loadChatGPTApiKey()
        
        // Generate the HTML immediately if we have an API key
        if !apiKey.isEmpty || !chatgptApiKey.isEmpty {
            generateGeminiHTML()
        }
    }
    
    // MARK: - API Key Management
    
    private func saveApiKey() {
        UserDefaults.standard.set(apiKey, forKey: "geminiApiKey")
    }
    
    private func loadApiKey() {
        if let savedKey = UserDefaults.standard.string(forKey: "geminiApiKey") {
            apiKey = savedKey
        }
    }
    
    private func saveChatGPTApiKey() {
        UserDefaults.standard.set(chatgptApiKey, forKey: "chatgptApiKey")
    }
    
    private func loadChatGPTApiKey() {
        if let savedKey = UserDefaults.standard.string(forKey: "chatgptApiKey") {
            chatgptApiKey = savedKey
        }
    }
    
    // Public method to update API key from external sources
    func updateApiKey(_ newKey: String) {
        print("GeminiAPIManager: Updating Gemini API key")
        apiKey = newKey
    }
    
    func updateChatGPTApiKey(_ newKey: String) {
        print("GeminiAPIManager: Updating ChatGPT API key")
        chatgptApiKey = newKey
    }
    
    // MARK: - HTML Generation
    
    func generateGeminiHTML() {
        // Generate the HTML file - Gemini if present, else ChatGPT if present, else missing
        let htmlContent: String
        if !apiKey.isEmpty {
            htmlContent = generateGeminiHTMLContent()
        } else if !chatgptApiKey.isEmpty {
            htmlContent = generateChatGPTHTMLContent()
        } else {
            htmlContent = generateAPIKeyMissingHTML()
        }
        
        let htmlURL = htmlDirectoryURL.appendingPathComponent("index.html")
        
        do {
            try htmlContent.write(to: htmlURL, atomically: true, encoding: .utf8)
            print("Provider HTML generated at: \(htmlURL.path)")
        } catch {
            print("Error writing provider HTML: \(error)")
        }
        
        // Generate the CSS file
        let cssContent = generateCSSContent()
        let cssURL = htmlDirectoryURL.appendingPathComponent("styles.css")
        
        do {
            try cssContent.write(to: cssURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error writing CSS: \(error)")
        }
        
        // Generate the JavaScript file for the selected provider
        if !apiKey.isEmpty || !chatgptApiKey.isEmpty {
            let jsContent = !apiKey.isEmpty ? generateGeminiJSContent() : generateOpenAIJSContent()
            let jsURL = htmlDirectoryURL.appendingPathComponent("script.js")
            do {
                try jsContent.write(to: jsURL, atomically: true, encoding: .utf8)
            } catch {
                print("Error writing JS: \(error)")
            }
        }
    }
    
    func getGeminiURL() -> URL? {
        let htmlURL = htmlDirectoryURL.appendingPathComponent("index.html")
        if FileManager.default.fileExists(atPath: htmlURL.path) {
            return htmlURL
        }
        return nil
    }
    
    // Force reload the WebView when API key status changes
    private func reloadWebView() {
        // Regenerate HTML content first - critical to ensure we're showing the correct view
        generateGeminiHTML()
        
        // Post notification to reload askAppleAI WebView using a consistent identifier
        // Pass whether both keys are empty so the WebView knows whether to show API key message or chat interface
        NotificationCenter.default.post(name: NSNotification.Name("ReloadAskAppleAIWebView"), object: "askAppleAI")
        
        print("GeminiAPIManager: Reloading WebView, Provider = \(!apiKey.isEmpty ? "Gemini" : (!chatgptApiKey.isEmpty ? "ChatGPT" : "None"))")
    }
    
    // MARK: - Content Generation
    
    // Generate HTML for the API key missing message
    private func generateAPIKeyMissingHTML() -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>askAppleAI</title>
            <link rel="stylesheet" href="styles.css">
            <style>
                :root { color-scheme: light dark; }
                body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 0; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: var(--bg); color: var(--fg); }
                .api-key-message { text-align: center; padding: 30px; background-color: var(--card); border-radius: 12px; box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1); max-width: 90%; width: 520px; }
                h1 { font-size: 28px; margin-bottom: 20px; color: var(--fg-strong); }
                p { font-size: 16px; color: var(--fg-muted); margin-bottom: 20px; line-height: 1.5; }
                :root { --bg: #f5f5f7; --card: #ffffff; --fg: #1d1d1f; --fg-strong: #1d1d1f; --fg-muted: #6e6e73; }
                @media (prefers-color-scheme: dark) {
                    :root { --bg: #18191a; --card: #232526; --fg: #ffffff; --fg-strong: #ffffff; --fg-muted: #b0b0b5; }
                }
            </style>
        </head>
        <body>
            <div class="api-key-message">
                <h1>askAppleAI</h1>
                <p>Please add your Gemini or ChatGPT API key in Preferences to use this feature.</p>
            </div>
        </body>
        </html>
        """
    }
    
    private func generateGeminiHTMLContent() -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>askAppleAI Chat Interface</title>
            <link rel="stylesheet" href="styles.css">
        </head>
        <body>
            <div class="chat-container">
                <div class="chat-header">
                    <img src="data:image/png;base64,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" alt="askAppleAI" class="chat-logo">
                    <h1>askAppleAI</h1>
                </div>
                <div class="chat-messages" id="chat-messages">
                    <div class="welcome-message">
                        <h2>Welcome to askAppleAI</h2>
                        <p>How can I help you today?</p>
                    </div>
                </div>
                <div class="chat-input-container">
                    <div class="chat-input-row">
                        <textarea id="user-input" placeholder="Type your message here..." rows="1" autofocus></textarea>
                        <button id="send-button">Send</button>
                    </div>
                </div>
            </div>
            <script>
                const PROVIDER = "gemini";
                const GEMINI_API_KEY = "\(apiKey)";
            </script>
            <script src="script.js"></script>
        </body>
        </html>
        """
    }
    
    private func generateChatGPTHTMLContent() -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>askAppleAI Chat Interface</title>
            <link rel="stylesheet" href="styles.css">
        </head>
        <body>
            <div class="chat-container">
                <div class="chat-header">
                    <img src="data:image/png;base64,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" alt="askAppleAI" class="chat-logo">
                    <h1>askAppleAI</h1>
                </div>
                <div class="chat-messages" id="chat-messages">
                    <div class="welcome-message">
                        <h2>Welcome to askAppleAI</h2>
                        <p>How can I help you today?</p>
                    </div>
                </div>
                <div class="chat-input-container">
                    <div class="chat-input-row">
                        <textarea id="user-input" placeholder="Type your message here..." rows="1" autofocus></textarea>
                        <button id="send-button">Send</button>
                    </div>
                </div>
            </div>
            <script>
                const PROVIDER = "openai";
                const OPENAI_API_KEY = "\(chatgptApiKey)";
            </script>
            <script src="script.js"></script>
        </body>
        </html>
        """
    }
    
    private func generateCSSContent() -> String {
        return """
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        }

        body {
            color-scheme: light dark;
            background-color: var(--background-color);
            color: var(--text-color);
        }
        :root {
            --background-color: #f5f5f7;
            --container-bg: #ffffff;
            --border-color: #e6e6e6;
            --input-bg: #ffffff;
            --input-border: #d2d2d7;
            --user-message-bg: #007aff;
            --user-message-text: #fff;
            --bot-message-bg: #fff;
            --bot-message-text: #1d1d1f;
            --text-color: #1d1d1f;
            --shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --background-color: #18191a;
                --container-bg: #232526;
                --border-color: #33343a;
                --input-bg: #232526;
                --input-border: #44454a;
                --user-message-bg: #0a84ff;
                --user-message-text: #fff;
                --bot-message-bg: #232526;
                --bot-message-text: #ffffff;
                --text-color: #ffffff;
                --shadow: 0 1px 3px rgba(0, 0, 0, 0.5);
            }
        }
        .chat-container {
            max-width: 100%;
            height: 100vh;
            margin: 0 auto;
            display: flex;
            flex-direction: column;
        }
        .chat-header {
            background-color: var(--container-bg);
            padding: 16px;
            text-align: center;
            display: flex;
            align-items: center;
            justify-content: center;
            border-bottom: 1px solid var(--border-color);
        }
        .chat-header h1 { font-size: 18px; font-weight: 500; margin-left: 10px; }
        .chat-logo { width: 24px; height: 24px; }
        .chat-messages { flex: 1; padding: 16px; overflow-y: auto; background-color: var(--background-color); }
        .welcome-message { background-color: var(--container-bg); padding: 20px; border-radius: 12px; margin-bottom: 16px; box-shadow: var(--shadow); text-align: center; }
        .welcome-message h2 { font-size: 20px; margin-bottom: 8px; color: var(--text-color); }
        .welcome-message p { color: var(--bot-message-text); font-size: 16px; }
        .message { margin-bottom: 16px; display: flex; flex-direction: column; }
        .user-message { align-items: flex-end; }
        .bot-message { align-items: flex-start; }
        .message-content { padding: 12px 16px; border-radius: 18px; max-width: 80%; word-wrap: break-word; }
        .user-message .message-content { background-color: var(--user-message-bg); color: var(--user-message-text); border-bottom-right-radius: 4px; }
        .bot-message .message-content { background-color: var(--bot-message-bg); color: var(--bot-message-text); border-bottom-left-radius: 4px; box-shadow: var(--shadow); }
        .chat-input-container { background-color: var(--container-bg); border-top: 1px solid var(--border-color); padding: 16px; }
        .chat-input-row { display: flex; flex-direction: row; align-items: center; gap: 8px; }
        #user-input { flex: 1 1 auto; padding: 12px; background: var(--input-bg); border: 1px solid var(--input-border); border-radius: 20px; resize: none; font-size: 16px; outline: none; max-height: 120px; margin-bottom: 0; color: var(--text-color); }
        #send-button { background-color: #007aff; color: white; border: none; border-radius: 20px; padding: 8px 20px; font-size: 16px; cursor: pointer; margin-left: 8px; }
        #send-button:hover { background-color: #0071e3; }
        pre { background-color: #f2f2f7; padding: 12px; border-radius: 8px; overflow-x: auto; margin: 8px 0; }
        code { font-family: Monaco, monospace; font-size: 14px; }
        ul, ol { margin-left: 24px; margin-top: 8px; margin-bottom: 8px; }
        a { color: #007aff; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .bot-message p { margin-bottom: 8px; }
        .bot-message p:last-child { margin-bottom: 0; }
        .bot-message h1, .bot-message h2, .bot-message h3 { margin-top: 16px; margin-bottom: 8px; }
        .thinking { display: flex; padding: 8px 0; }
        .dot { width: 8px; height: 8px; margin: 0 4px; background-color: #d2d2d7; border-radius: 50%; animation: bounce 1.5s infinite ease-in-out; }
        .dot:nth-child(1) { animation-delay: 0s; }
        .dot:nth-child(2) { animation-delay: 0.2s; }
        .dot:nth-child(3) { animation-delay: 0.4s; }
        @keyframes bounce { 0%, 80%, 100% { transform: translateY(0); } 40% { transform: translateY(-8px); } }
        """
    }
    
    private func generateGeminiJSContent() -> String {
        return #"""
        document.addEventListener('DOMContentLoaded', function() {
            const chatMessages = document.getElementById('chat-messages');
            const userInput = document.getElementById('user-input');
            const sendButton = document.getElementById('send-button');
            
            // Adjust textarea height as user types
            userInput.addEventListener('input', function() {
                this.style.height = 'auto';
                this.style.height = (this.scrollHeight) + 'px';
            });
            
            // Send message on Enter key (but allow Shift+Enter for new line)
            userInput.addEventListener('keydown', function(e) {
                if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    sendMessage();
                }
            });
            
            // Send button click
            sendButton.addEventListener('click', sendMessage);
            
            // Test API key on page load
            if (GEMINI_API_KEY && GEMINI_API_KEY.trim() !== '') {
                console.log('API Key loaded:', GEMINI_API_KEY.substring(0, 10) + '...');
                testApiKey();
                // Show welcome message when API key is available
                addMessage("Hello! I'm askAppleAI powered by Google Gemini. How can I help you today?", 'bot');
            } else {
                console.log('No API key found');
                // Show message to add API key when none is provided
                addMessage("👋 Welcome to askAppleAI! To start chatting, please add your Gemini API key in Preferences. Go to Preferences → API Keys → Gemini API Key → Click 'Apply'.", 'bot');
            }
            
            function sendMessage() {
                const message = userInput.value.trim();
                if (message === '') return;
                
                if (!GEMINI_API_KEY || GEMINI_API_KEY.trim() === '') {
                    addMessage("Please add your Gemini API key in Preferences first.", 'bot');
                    return;
                }
                
                addMessage(message, 'user');
                userInput.value = '';
                userInput.style.height = 'auto';
                addThinkingIndicator();
                generateGeminiResponse(message);
            }
            
            function addMessage(content, sender) {
                const messageDiv = document.createElement('div');
                messageDiv.className = `message ${sender}-message`;
                const messageContent = document.createElement('div');
                messageContent.className = 'message-content';
                if (sender === 'bot') { messageContent.innerHTML = formatBotMessage(content); } else { messageContent.textContent = content; }
                messageDiv.appendChild(messageContent);
                chatMessages.appendChild(messageDiv);
                chatMessages.scrollTop = chatMessages.scrollHeight;
            }
            
            function formatBotMessage(content) {
                content = content.replace(/```([\s\S]*?)```/g, '<pre><code>$1</code></pre>');
                content = content.replace(/`([^`]+)`/g, '<code>$1</code>');
                content = content.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
                content = content.replace(/\*([^*]+)\*/g, '<em>$1</em>');
                content = content.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank">$1</a>');
                content = '<p>' + content.replace(/\n\s*\n/g, '</p><p>') + '</p>';
                content = content.replace(/\n/g, '<br>');
                return content;
            }
            
            function addThinkingIndicator() {
                const thinkingDiv = document.createElement('div');
                thinkingDiv.className = 'message bot-message';
                thinkingDiv.id = 'thinking-indicator';
                const thinkingContent = document.createElement('div');
                thinkingContent.className = 'message-content thinking';
                for (let i = 0; i < 3; i++) { const dot = document.createElement('div'); dot.className = 'dot'; thinkingContent.appendChild(dot); }
                thinkingDiv.appendChild(thinkingContent);
                chatMessages.appendChild(thinkingDiv);
                chatMessages.scrollTop = chatMessages.scrollHeight;
            }
            
            function removeThinkingIndicator() {
                const thinkingIndicator = document.getElementById('thinking-indicator');
                if (thinkingIndicator) { thinkingIndicator.remove(); }
            }
            
            async function testApiKey() {
                try {
                    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${GEMINI_API_KEY}`);
                    if (response.ok) { const data = await response.json(); console.log('Available models:', data.models ? data.models.map(m => m.name) : 'No models found'); }
                } catch (error) { console.error('❌ Error testing API key:', error); }
            }
            
            async function generateGeminiResponse(prompt) {
                try {
                    const models = ['gemini-1.5-flash','gemini-1.5-pro','gemini-pro','gemini-1.0-pro'];
                    let lastError = null;
                    for (const model of models) {
                        try {
                            const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }], generationConfig: { temperature: 0.7, topK: 40, topP: 0.95, maxOutputTokens: 2048 } }) });
                            if (!response.ok) { lastError = new Error('request failed'); continue; }
                            const data = await response.json(); removeThinkingIndicator();
                            if (data.candidates && data.candidates.length > 0 && data.candidates[0].content && data.candidates[0].content.parts && data.candidates[0].content.parts.length > 0) { const responseText = data.candidates[0].content.parts[0].text; addMessage(responseText, 'bot'); return; } else { lastError = new Error('Empty response'); continue; }
                        } catch (modelError) { lastError = modelError; continue; }
                    }
                    removeThinkingIndicator(); addMessage("Sorry, there was an error communicating with Gemini.", 'bot'); console.error('All models failed:', lastError);
                } catch (error) { console.error('Error calling Gemini API:', error); removeThinkingIndicator(); addMessage("Sorry, there was an error communicating with Gemini.", 'bot'); }
            }
        });
        """#
    }
    
    private func generateOpenAIJSContent() -> String {
        return #"""
        document.addEventListener('DOMContentLoaded', function() {
            const chatMessages = document.getElementById('chat-messages');
            const userInput = document.getElementById('user-input');
            const sendButton = document.getElementById('send-button');
            
            userInput.addEventListener('input', function() { this.style.height = 'auto'; this.style.height = (this.scrollHeight) + 'px'; });
            userInput.addEventListener('keydown', function(e) { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); } });
            sendButton.addEventListener('click', sendMessage);
            
            if (OPENAI_API_KEY && OPENAI_API_KEY.trim() !== '') {
                addMessage("Hello! I'm askAppleAI powered by OpenAI. How can I help you today?", 'bot');
                            } else {
                addMessage("👋 Welcome to askAppleAI! Please add your ChatGPT API key in Preferences.", 'bot');
            }
            
            async function sendMessage() {
                const message = userInput.value.trim(); if (message === '') return;
                if (!OPENAI_API_KEY || OPENAI_API_KEY.trim() === '') { addMessage("Please add your ChatGPT API key in Preferences first.", 'bot'); return; }
                addMessage(message, 'user'); userInput.value=''; userInput.style.height='auto'; addThinkingIndicator();
                try {
                    const response = await fetch('https://api.openai.com/v1/chat/completions', { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${OPENAI_API_KEY}` }, body: JSON.stringify({ model: 'gpt-4o-mini', messages: [{ role: 'user', content: message }] }) });
                    const data = await response.json(); removeThinkingIndicator();
                    const text = data.choices && data.choices[0] && data.choices[0].message && data.choices[0].message.content ? data.choices[0].message.content : 'Sorry, no response.';
                    addMessage(text, 'bot');
                } catch (e) { removeThinkingIndicator(); addMessage("Sorry, there was an error communicating with ChatGPT.", 'bot'); }
            }
            function addMessage(content, sender) { const messageDiv = document.createElement('div'); messageDiv.className = `message ${sender}-message`; const messageContent = document.createElement('div'); messageContent.className = 'message-content'; if (sender === 'bot') { messageContent.innerHTML = format(content); } else { messageContent.textContent = content; } messageDiv.appendChild(messageContent); chatMessages.appendChild(messageDiv); chatMessages.scrollTop = chatMessages.scrollHeight; }
            function addThinkingIndicator() { const thinkingDiv = document.createElement('div'); thinkingDiv.className='message bot-message'; thinkingDiv.id='thinking-indicator'; const thinkingContent=document.createElement('div'); thinkingContent.className='message-content thinking'; for (let i=0;i<3;i++){ const dot=document.createElement('div'); dot.className='dot'; thinkingContent.appendChild(dot);} thinkingDiv.appendChild(thinkingContent); chatMessages.appendChild(thinkingDiv); chatMessages.scrollTop = chatMessages.scrollHeight; }
            function removeThinkingIndicator(){ const t=document.getElementById('thinking-indicator'); if(t){ t.remove(); }}
            function format(content){ content = content.replace(/```([\s\S]*?)```/g, '<pre><code>$1</code></pre>'); content = content.replace(/`([^`]+)`/g, '<code>$1</code>'); content = content.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>'); content = content.replace(/\*([^*]+)\*/g, '<em>$1</em>'); content = content.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank">$1</a>'); content = '<p>' + content.replace(/\n\s*\n/g, '</p><p>') + '</p>'; content = content.replace(/\n/g, '<br>'); return content; }
        });
        """#
    }
}

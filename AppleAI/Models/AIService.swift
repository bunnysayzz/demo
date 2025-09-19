import Foundation
import SwiftUI
import Combine

struct AIService: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let url: URL
    let color: Color
    let isCustom: Bool
    
    init(name: String, icon: String, url: URL, color: Color, isCustom: Bool = false) {
        self.name = name
        self.icon = icon
        self.url = url
        self.color = color
        self.isCustom = isCustom
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AIService, rhs: AIService) -> Bool {
        return lhs.id == rhs.id
    }
}

// Function to get the askAppleAI URL
func getAskAppleAIURL() -> URL {
    // Using a placeholder URL since GeminiAPIManager will handle the actual URL at runtime
    // This ensures that AIService initialization doesn't fail, and the real URL is loaded later
    let fileManager = FileManager.default
    let tempDirectory = fileManager.temporaryDirectory
    return tempDirectory
}

// Predefined AI services
let aiServices = [
    AIService(
        name: "ChatGPT",
        icon: "AILogos/chatgpt",
        url: URL(string: "https://chat.openai.com")!,
        color: Color.green
    ),
    AIService(
        name: "Claude",
        icon: "AILogos/claude",
        url: URL(string: "https://claude.ai")!,
        color: Color.purple
    ),
    AIService(
        name: "Copilot",
        icon: "AILogos/copilot",
        url: URL(string: "https://copilot.microsoft.com")!,
        color: Color.blue
    ),
    AIService(
        name: "Perplexity",
        icon: "AILogos/perplexity",
        url: URL(string: "https://www.perplexity.ai")!,
        color: Color.orange
    ),
    AIService(
        name: "DeepSeek",
        icon: "AILogos/deekseek",
        url: URL(string: "https://chat.deepseek.com")!,
        color: Color.red
    ),
    AIService(
        name: "Grok",
        icon: "AILogos/grok",
        url: URL(string: "https://grok.com/?referrer=website")!,
        color: Color(red: 0.0, green: 0.6, blue: 0.9)
    ),
    AIService(
        name: "Mistral",
        icon: "AILogos/mistral",
        url: URL(string: "https://chat.mistral.ai")!,
        color: Color(red: 0.2, green: 0.4, blue: 0.8)
    ),
    AIService(
        name: "Gemini",
        icon: "AILogos/gemini",
        url: URL(string: "https://gemini.google.com")!,
        color: Color(red: 0.0, green: 0.7, blue: 0.7)
    ),
    AIService(
        name: "Pi",
        icon: "AILogos/pi",
        url: URL(string: "https://pi.ai")!,
        color: Color(red: 0.8, green: 0.4, blue: 0.2)
    ),
    // New services from Free version
    AIService(
        name: "Blackbox",
        icon: "AILogos/blackbox",
        url: URL(string: "https://www.blackbox.ai")!,
        color: Color(red: 0.15, green: 0.15, blue: 0.15)
    ),
    AIService(
        name: "Meta",
        icon: "AILogos/meta",
        url: URL(string: "https://www.meta.ai")!,
        color: Color(red: 0.00, green: 0.55, blue: 0.95)
    ),
    AIService(
        name: "Zhipu AI",
        icon: "AILogos/zhipu",
        url: URL(string: "https://chat.z.ai")!,
        color: Color(red: 0.25, green: 0.45, blue: 1.0)
    ),
    AIService(
        name: "MCP Chat",
        icon: "AILogos/mcpchat",
        url: URL(string: "https://mcpchat.scira.ai")!,
        color: Color(red: 0.40, green: 0.30, blue: 0.95)
    ),
    AIService(
        name: "askAppleAI",
        icon: "AILogos/appleai",
        url: getAskAppleAIURL(),
        color: Color(red: 0.3, green: 0.3, blue: 0.3),
        isCustom: true
    )
] 
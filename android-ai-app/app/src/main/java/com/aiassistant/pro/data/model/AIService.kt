package com.aiassistant.pro.data.model

import android.os.Parcelable
import androidx.compose.ui.graphics.Color
import kotlinx.parcelize.Parcelize
import kotlinx.serialization.Serializable

@Parcelize
@Serializable
data class AIService(
    val id: String,
    val name: String,
    val displayName: String,
    val url: String,
    val iconResource: String,
    val color: Long, // Color as Long for serialization
    val isEnabled: Boolean = true,
    val isVisible: Boolean = true,
    val supportsFileUpload: Boolean = true,
    val supportsVoice: Boolean = false,
    val category: AIServiceCategory = AIServiceCategory.GENERAL,
    val description: String = "",
    val features: List<String> = emptyList()
) : Parcelable

@Parcelize
@Serializable
enum class AIServiceCategory : Parcelable {
    GENERAL,
    CODING,
    CREATIVE,
    RESEARCH,
    CUSTOM
}

// Extension to convert Long back to Color
val AIService.colorValue: Color
    get() = Color(color)

// Predefined AI services matching the macOS version
object AIServices {
    val chatGPT = AIService(
        id = "chatgpt",
        name = "ChatGPT",
        displayName = "ChatGPT",
        url = "https://chat.openai.com",
        iconResource = "chatgpt",
        color = 0xFF10A37F, // ChatGPT green
        supportsVoice = true,
        category = AIServiceCategory.GENERAL,
        description = "OpenAI's conversational AI assistant",
        features = listOf("Conversation", "Code", "Writing", "Analysis", "Voice Chat")
    )
    
    val claude = AIService(
        id = "claude",
        name = "Claude",
        displayName = "Claude",
        url = "https://claude.ai",
        iconResource = "claude",
        color = 0xFFD97706, // Claude orange
        category = AIServiceCategory.GENERAL,
        description = "Anthropic's helpful, harmless, and honest AI assistant",
        features = listOf("Conversation", "Analysis", "Writing", "Code Review")
    )
    
    val copilot = AIService(
        id = "copilot",
        name = "Copilot",
        displayName = "GitHub Copilot",
        url = "https://copilot.microsoft.com",
        iconResource = "copilot",
        color = 0xFF0969DA, // GitHub blue
        supportsVoice = true,
        category = AIServiceCategory.CODING,
        description = "Microsoft's AI-powered coding assistant",
        features = listOf("Code Generation", "Chat", "Voice Commands", "Code Explanation")
    )
    
    val perplexity = AIService(
        id = "perplexity",
        name = "Perplexity",
        displayName = "Perplexity AI",
        url = "https://www.perplexity.ai",
        iconResource = "perplexity",
        color = 0xFF6366F1, // Perplexity purple
        category = AIServiceCategory.RESEARCH,
        description = "AI-powered search and research assistant",
        features = listOf("Web Search", "Research", "Citations", "Real-time Information")
    )
    
    val deepSeek = AIService(
        id = "deepseek",
        name = "DeepSeek",
        displayName = "DeepSeek",
        url = "https://chat.deepseek.com",
        iconResource = "deepseek",
        color = 0xFFEF4444, // DeepSeek red
        category = AIServiceCategory.CODING,
        description = "Advanced AI model for coding and reasoning",
        features = listOf("Code Generation", "Math", "Reasoning", "Problem Solving")
    )
    
    val grok = AIService(
        id = "grok",
        name = "Grok",
        displayName = "Grok",
        url = "https://grok.com/?referrer=website",
        iconResource = "grok",
        color = 0xFF1DA1F2, // Twitter/X blue
        category = AIServiceCategory.GENERAL,
        description = "xAI's witty and rebellious AI assistant",
        features = listOf("Conversation", "Humor", "Real-time Info", "Uncensored")
    )
    
    val mistral = AIService(
        id = "mistral",
        name = "Mistral",
        displayName = "Mistral AI",
        url = "https://chat.mistral.ai",
        iconResource = "mistral",
        color = 0xFF3B82F6, // Mistral blue
        isVisible = false, // Hidden by default like macOS version
        category = AIServiceCategory.GENERAL,
        description = "European AI assistant focused on efficiency",
        features = listOf("Multilingual", "Efficient", "Privacy-focused")
    )
    
    val gemini = AIService(
        id = "gemini",
        name = "Gemini",
        displayName = "Google Gemini",
        url = "https://gemini.google.com",
        iconResource = "gemini",
        color = 0xFF4285F4, // Google blue
        isVisible = false, // Hidden by default like macOS version
        supportsVoice = true,
        category = AIServiceCategory.GENERAL,
        description = "Google's most capable AI model",
        features = listOf("Multimodal", "Code", "Creative", "Analysis", "Integration")
    )
    
    val pi = AIService(
        id = "pi",
        name = "Pi",
        displayName = "Pi AI",
        url = "https://pi.ai",
        iconResource = "pi",
        color = 0xFFF59E0B, // Pi amber
        isVisible = false, // Hidden by default like macOS version
        supportsVoice = true,
        category = AIServiceCategory.GENERAL,
        description = "Personal AI companion by Inflection AI",
        features = listOf("Personal Assistant", "Emotional Support", "Voice Chat")
    )
    
    val blackbox = AIService(
        id = "blackbox",
        name = "Blackbox",
        displayName = "Blackbox AI",
        url = "https://www.blackbox.ai",
        iconResource = "blackbox",
        color = 0xFF262626, // Blackbox dark
        category = AIServiceCategory.CODING,
        description = "AI coding assistant for developers",
        features = listOf("Code Search", "Code Generation", "Real-time Coding")
    )
    
    val meta = AIService(
        id = "meta",
        name = "Meta",
        displayName = "Meta AI",
        url = "https://www.meta.ai",
        iconResource = "meta",
        color = 0xFF0084FF, // Meta blue
        category = AIServiceCategory.GENERAL,
        description = "Meta's AI assistant powered by Llama",
        features = listOf("Conversation", "Image Generation", "Creative Writing")
    )
    
    val zhipuAI = AIService(
        id = "zhipu",
        name = "Zhipu AI",
        displayName = "Zhipu AI",
        url = "https://chat.z.ai",
        iconResource = "zhipu",
        color = 0xFF4F46E5, // Zhipu indigo
        category = AIServiceCategory.GENERAL,
        description = "Chinese AI model with strong reasoning capabilities",
        features = listOf("Multilingual", "Reasoning", "Chinese Language Expert")
    )
    
    val mcpChat = AIService(
        id = "mcpchat",
        name = "MCP Chat",
        displayName = "MCP Chat",
        url = "https://mcpchat.scira.ai",
        iconResource = "mcpchat",
        color = 0xFF7C3AED, // MCP purple
        category = AIServiceCategory.GENERAL,
        description = "Model Context Protocol enabled chat interface",
        features = listOf("Protocol Integration", "Advanced Context", "Tool Integration")
    )
    
    // Custom service placeholder
    val askAppleAI = AIService(
        id = "ask_apple_ai",
        name = "askAppleAI",
        displayName = "Ask Apple AI",
        url = "about:blank", // Will be dynamically set
        iconResource = "apple_ai",
        color = 0xFF4C4C4C, // Apple gray
        category = AIServiceCategory.CUSTOM,
        description = "Custom AI service integration",
        features = listOf("Custom Integration", "API Access")
    )
    
    // List of all available services
    val allServices = listOf(
        chatGPT,
        claude,
        copilot,
        perplexity,
        deepSeek,
        grok,
        mistral,
        gemini,
        pi,
        blackbox,
        meta,
        zhipuAI,
        mcpChat,
        askAppleAI
    )
    
    // Get service by ID
    fun getServiceById(id: String): AIService? {
        return allServices.find { it.id == id }
    }
    
    // Get visible services
    fun getVisibleServices(): List<AIService> {
        return allServices.filter { it.isVisible }
    }
    
    // Get services by category
    fun getServicesByCategory(category: AIServiceCategory): List<AIService> {
        return allServices.filter { it.category == category }
    }
}
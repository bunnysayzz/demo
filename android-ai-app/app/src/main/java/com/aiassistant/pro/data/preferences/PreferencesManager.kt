package com.aiassistant.pro.data.preferences

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import com.aiassistant.pro.data.model.AIService
import com.aiassistant.pro.data.model.AIServices
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "ai_assistant_preferences")

@Singleton
class PreferencesManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val dataStore = context.dataStore
    
    companion object {
        // General preferences
        val ALWAYS_ON_TOP = booleanPreferencesKey("always_on_top")
        val FLOATING_WINDOW_ENABLED = booleanPreferencesKey("floating_window_enabled")
        val AUTO_START_FLOATING = booleanPreferencesKey("auto_start_floating")
        val THEME_MODE = stringPreferencesKey("theme_mode") // "light", "dark", "system"
        val DYNAMIC_COLOR = booleanPreferencesKey("dynamic_color")
        
        // Window preferences
        val WINDOW_WIDTH = intPreferencesKey("window_width")
        val WINDOW_HEIGHT = intPreferencesKey("window_height")
        val WINDOW_X = intPreferencesKey("window_x")
        val WINDOW_Y = intPreferencesKey("window_y")
        val PINNED_POSITION_ENABLED = booleanPreferencesKey("pinned_position_enabled")
        
        // Service preferences
        val SELECTED_SERVICE_ID = stringPreferencesKey("selected_service_id")
        val LAST_USED_SERVICE = stringPreferencesKey("last_used_service")
        
        // Feature preferences
        val QUICK_TILE_ENABLED = booleanPreferencesKey("quick_tile_enabled")
        val NOTIFICATION_ENABLED = booleanPreferencesKey("notification_enabled")
        val VOICE_INPUT_ENABLED = booleanPreferencesKey("voice_input_enabled")
        val FILE_UPLOAD_ENABLED = booleanPreferencesKey("file_upload_enabled")
        val SCREENSHOT_ENABLED = booleanPreferencesKey("screenshot_enabled")
        
        // Keyboard shortcuts
        val GLOBAL_SHORTCUT_ENABLED = booleanPreferencesKey("global_shortcut_enabled")
        val SHORTCUT_KEY_CODE = intPreferencesKey("shortcut_key_code")
        val SHORTCUT_MODIFIERS = intPreferencesKey("shortcut_modifiers")
        
        // API Keys
        val GEMINI_API_KEY = stringPreferencesKey("gemini_api_key")
        val OPENAI_API_KEY = stringPreferencesKey("openai_api_key")
        val ANTHROPIC_API_KEY = stringPreferencesKey("anthropic_api_key")
        
        // Privacy
        val ANALYTICS_ENABLED = booleanPreferencesKey("analytics_enabled")
        val CRASH_REPORTING_ENABLED = booleanPreferencesKey("crash_reporting_enabled")
        
        // App info
        val FIRST_LAUNCH = booleanPreferencesKey("first_launch")
        val APP_VERSION = stringPreferencesKey("app_version")
        val LAST_UPDATE_CHECK = longPreferencesKey("last_update_check")
    }
    
    // Model visibility preferences - dynamic keys
    private fun getModelVisibilityKey(serviceId: String) = booleanPreferencesKey("model_visible_$serviceId")
    
    // General preferences
    val alwaysOnTop: Flow<Boolean> = dataStore.data.map { preferences ->
        preferences[ALWAYS_ON_TOP] ?: false
    }
    
    suspend fun setAlwaysOnTop(enabled: Boolean) {
        dataStore.edit { preferences ->
            preferences[ALWAYS_ON_TOP] = enabled
        }
    }
    
    val floatingWindowEnabled: Flow<Boolean> = dataStore.data.map { preferences ->
        preferences[FLOATING_WINDOW_ENABLED] ?: false
    }
    
    suspend fun setFloatingWindowEnabled(enabled: Boolean) {
        dataStore.edit { preferences ->
            preferences[FLOATING_WINDOW_ENABLED] = enabled
        }
    }
    
    val autoStartFloating: Flow<Boolean> = dataStore.data.map { preferences ->
        preferences[AUTO_START_FLOATING] ?: false
    }
    
    suspend fun setAutoStartFloating(enabled: Boolean) {
        dataStore.edit { preferences ->
            preferences[AUTO_START_FLOATING] = enabled
        }
    }
    
    val themeMode: Flow<String> = dataStore.data.map { preferences ->
        preferences[THEME_MODE] ?: "system"
    }
    
    suspend fun setThemeMode(mode: String) {
        dataStore.edit { preferences ->
            preferences[THEME_MODE] = mode
        }
    }
    
    val dynamicColor: Flow<Boolean> = dataStore.data.map { preferences ->
        preferences[DYNAMIC_COLOR] ?: true
    }
    
    suspend fun setDynamicColor(enabled: Boolean) {
        dataStore.edit { preferences ->
            preferences[DYNAMIC_COLOR] = enabled
        }
    }
    
    // Window preferences
    val windowDimensions: Flow<WindowDimensions> = dataStore.data.map { preferences ->
        WindowDimensions(
            width = preferences[WINDOW_WIDTH] ?: 400,
            height = preferences[WINDOW_HEIGHT] ?: 600,
            x = preferences[WINDOW_X] ?: -1,
            y = preferences[WINDOW_Y] ?: -1
        )
    }
    
    suspend fun setWindowDimensions(width: Int, height: Int, x: Int = -1, y: Int = -1) {
        dataStore.edit { preferences ->
            preferences[WINDOW_WIDTH] = width
            preferences[WINDOW_HEIGHT] = height
            if (x != -1) preferences[WINDOW_X] = x
            if (y != -1) preferences[WINDOW_Y] = y
        }
    }
    
    val pinnedPositionEnabled: Flow<Boolean> = dataStore.data.map { preferences ->
        preferences[PINNED_POSITION_ENABLED] ?: false
    }
    
    suspend fun setPinnedPositionEnabled(enabled: Boolean) {
        dataStore.edit { preferences ->
            preferences[PINNED_POSITION_ENABLED] = enabled
        }
    }
    
    // Service preferences
    val selectedServiceId: Flow<String> = dataStore.data.map { preferences ->
        preferences[SELECTED_SERVICE_ID] ?: AIServices.chatGPT.id
    }
    
    suspend fun setSelectedServiceId(serviceId: String) {
        dataStore.edit { preferences ->
            preferences[SELECTED_SERVICE_ID] = serviceId
            preferences[LAST_USED_SERVICE] = serviceId
        }
    }
    
    val lastUsedService: Flow<String> = dataStore.data.map { preferences ->
        preferences[LAST_USED_SERVICE] ?: AIServices.chatGPT.id
    }
    
    // Model visibility
    fun isModelVisible(serviceId: String): Flow<Boolean> = dataStore.data.map { preferences ->
        val key = getModelVisibilityKey(serviceId)
        val service = AIServices.getServiceById(serviceId)
        preferences[key] ?: service?.isVisible ?: true
    }
    
    suspend fun setModelVisibility(serviceId: String, visible: Boolean) {
        dataStore.edit { preferences ->
            val key = getModelVisibilityKey(serviceId)
            preferences[key] = visible
        }
    }
    
    // Get all model visibility states
    val allModelVisibility: Flow<Map<String, Boolean>> = dataStore.data.map { preferences ->
        AIServices.allServices.associate { service ->
            val key = getModelVisibilityKey(service.id)
            service.id to (preferences[key] ?: service.isVisible)
        }
    }
    
    // Feature preferences
    val quickTileEnabled: Flow<Boolean> = dataStore.data.map { preferences ->
        preferences[QUICK_TILE_ENABLED] ?: true
    }
    
    suspend fun setQuickTileEnabled(enabled: Boolean) {
        dataStore.edit { preferences ->
            preferences[QUICK_TILE_ENABLED] = enabled
        }
    }
    
    val notificationEnabled: Flow<Boolean> = dataStore.data.map { preferences ->
        preferences[NOTIFICATION_ENABLED] ?: true
    }
    
    suspend fun setNotificationEnabled(enabled: Boolean) {
        dataStore.edit { preferences ->
            preferences[NOTIFICATION_ENABLED] = enabled
        }
    }
    
    val voiceInputEnabled: Flow<Boolean> = dataStore.data.map { preferences ->
        preferences[VOICE_INPUT_ENABLED] ?: true
    }
    
    suspend fun setVoiceInputEnabled(enabled: Boolean) {
        dataStore.edit { preferences ->
            preferences[VOICE_INPUT_ENABLED] = enabled
        }
    }
    
    val fileUploadEnabled: Flow<Boolean> = dataStore.data.map { preferences ->
        preferences[FILE_UPLOAD_ENABLED] ?: true
    }
    
    suspend fun setFileUploadEnabled(enabled: Boolean) {
        dataStore.edit { preferences ->
            preferences[FILE_UPLOAD_ENABLED] = enabled
        }
    }
    
    val screenshotEnabled: Flow<Boolean> = dataStore.data.map { preferences ->
        preferences[SCREENSHOT_ENABLED] ?: true
    }
    
    suspend fun setScreenshotEnabled(enabled: Boolean) {
        dataStore.edit { preferences ->
            preferences[SCREENSHOT_ENABLED] = enabled
        }
    }
    
    // Keyboard shortcuts
    val globalShortcutEnabled: Flow<Boolean> = dataStore.data.map { preferences ->
        preferences[GLOBAL_SHORTCUT_ENABLED] ?: false
    }
    
    suspend fun setGlobalShortcutEnabled(enabled: Boolean) {
        dataStore.edit { preferences ->
            preferences[GLOBAL_SHORTCUT_ENABLED] = enabled
        }
    }
    
    // API Keys
    val geminiApiKey: Flow<String> = dataStore.data.map { preferences ->
        preferences[GEMINI_API_KEY] ?: ""
    }
    
    suspend fun setGeminiApiKey(key: String) {
        dataStore.edit { preferences ->
            preferences[GEMINI_API_KEY] = key
        }
    }
    
    val openaiApiKey: Flow<String> = dataStore.data.map { preferences ->
        preferences[OPENAI_API_KEY] ?: ""
    }
    
    suspend fun setOpenaiApiKey(key: String) {
        dataStore.edit { preferences ->
            preferences[OPENAI_API_KEY] = key
        }
    }
    
    val anthropicApiKey: Flow<String> = dataStore.data.map { preferences ->
        preferences[ANTHROPIC_API_KEY] ?: ""
    }
    
    suspend fun setAnthropicApiKey(key: String) {
        dataStore.edit { preferences ->
            preferences[ANTHROPIC_API_KEY] = key
        }
    }
    
    // Privacy
    val analyticsEnabled: Flow<Boolean> = dataStore.data.map { preferences ->
        preferences[ANALYTICS_ENABLED] ?: false
    }
    
    suspend fun setAnalyticsEnabled(enabled: Boolean) {
        dataStore.edit { preferences ->
            preferences[ANALYTICS_ENABLED] = enabled
        }
    }
    
    // App info
    val firstLaunch: Flow<Boolean> = dataStore.data.map { preferences ->
        preferences[FIRST_LAUNCH] ?: true
    }
    
    suspend fun setFirstLaunchComplete() {
        dataStore.edit { preferences ->
            preferences[FIRST_LAUNCH] = false
        }
    }
    
    suspend fun getFirstLaunchSync(): Boolean {
        return dataStore.data.first()[FIRST_LAUNCH] ?: true
    }
    
    // Reset all preferences
    suspend fun resetToDefaults() {
        dataStore.edit { preferences ->
            preferences.clear()
        }
    }
    
    // Reset model visibility to defaults
    suspend fun resetModelVisibilityToDefaults() {
        dataStore.edit { preferences ->
            AIServices.allServices.forEach { service ->
                val key = getModelVisibilityKey(service.id)
                preferences[key] = service.isVisible
            }
        }
    }
}

data class WindowDimensions(
    val width: Int,
    val height: Int,
    val x: Int,
    val y: Int
)
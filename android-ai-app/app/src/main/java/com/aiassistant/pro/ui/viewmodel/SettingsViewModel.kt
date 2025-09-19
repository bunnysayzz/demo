package com.aiassistant.pro.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aiassistant.pro.data.model.AIService
import com.aiassistant.pro.data.model.AIServices
import com.aiassistant.pro.data.preferences.PreferencesManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SettingsUiState(
    val isLoading: Boolean = false,
    val allServices: List<AIService> = AIServices.allServices,
    val modelVisibility: Map<String, Boolean> = emptyMap(),
    
    // General settings
    val alwaysOnTop: Boolean = false,
    val floatingWindowEnabled: Boolean = false,
    val autoStartFloating: Boolean = false,
    val hasOverlayPermission: Boolean = false,
    
    // Features
    val quickTileEnabled: Boolean = true,
    val notificationEnabled: Boolean = true,
    val voiceInputEnabled: Boolean = true,
    val fileUploadEnabled: Boolean = true,
    val screenshotEnabled: Boolean = true,
    
    // Appearance
    val themeMode: String = "system",
    val dynamicColor: Boolean = true,
    
    // API Keys
    val geminiApiKey: String = "",
    val openaiApiKey: String = "",
    val anthropicApiKey: String = "",
    
    // Privacy
    val analyticsEnabled: Boolean = false,
    
    // App info
    val appVersion: String = "1.0.0",
    val firstLaunch: Boolean = true,
    
    val error: String? = null
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val preferencesManager: PreferencesManager
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()
    
    init {
        observePreferences()
    }
    
    private fun observePreferences() {
        viewModelScope.launch {
            combine(
                preferencesManager.allModelVisibility,
                preferencesManager.alwaysOnTop,
                preferencesManager.floatingWindowEnabled,
                preferencesManager.autoStartFloating,
                preferencesManager.quickTileEnabled,
                preferencesManager.notificationEnabled,
                preferencesManager.voiceInputEnabled,
                preferencesManager.fileUploadEnabled,
                preferencesManager.screenshotEnabled,
                preferencesManager.themeMode,
                preferencesManager.dynamicColor,
                preferencesManager.geminiApiKey,
                preferencesManager.openaiApiKey,
                preferencesManager.anthropicApiKey,
                preferencesManager.analyticsEnabled,
                preferencesManager.firstLaunch
            ) { flows ->
                val modelVisibility = flows[0] as Map<String, Boolean>
                val alwaysOnTop = flows[1] as Boolean
                val floatingWindowEnabled = flows[2] as Boolean
                val autoStartFloating = flows[3] as Boolean
                val quickTileEnabled = flows[4] as Boolean
                val notificationEnabled = flows[5] as Boolean
                val voiceInputEnabled = flows[6] as Boolean
                val fileUploadEnabled = flows[7] as Boolean
                val screenshotEnabled = flows[8] as Boolean
                val themeMode = flows[9] as String
                val dynamicColor = flows[10] as Boolean
                val geminiApiKey = flows[11] as String
                val openaiApiKey = flows[12] as String
                val anthropicApiKey = flows[13] as String
                val analyticsEnabled = flows[14] as Boolean
                val firstLaunch = flows[15] as Boolean
                
                SettingsUiState(
                    allServices = AIServices.allServices,
                    modelVisibility = modelVisibility,
                    alwaysOnTop = alwaysOnTop,
                    floatingWindowEnabled = floatingWindowEnabled,
                    autoStartFloating = autoStartFloating,
                    quickTileEnabled = quickTileEnabled,
                    notificationEnabled = notificationEnabled,
                    voiceInputEnabled = voiceInputEnabled,
                    fileUploadEnabled = fileUploadEnabled,
                    screenshotEnabled = screenshotEnabled,
                    themeMode = themeMode,
                    dynamicColor = dynamicColor,
                    geminiApiKey = geminiApiKey,
                    openaiApiKey = openaiApiKey,
                    anthropicApiKey = anthropicApiKey,
                    analyticsEnabled = analyticsEnabled,
                    firstLaunch = firstLaunch
                )
            }.catch { error ->
                _uiState.value = _uiState.value.copy(
                    error = error.message ?: "Unknown error occurred"
                )
            }.collect { newState ->
                _uiState.value = newState
            }
        }
    }
    
    // Model visibility
    fun setModelVisibility(serviceId: String, visible: Boolean) {
        viewModelScope.launch {
            preferencesManager.setModelVisibility(serviceId, visible)
        }
    }
    
    fun resetModelVisibilityToDefaults() {
        viewModelScope.launch {
            preferencesManager.resetModelVisibilityToDefaults()
        }
    }
    
    // General settings
    fun setAlwaysOnTop(enabled: Boolean) {
        viewModelScope.launch {
            preferencesManager.setAlwaysOnTop(enabled)
        }
    }
    
    fun setFloatingWindowEnabled(enabled: Boolean) {
        viewModelScope.launch {
            preferencesManager.setFloatingWindowEnabled(enabled)
        }
    }
    
    fun setAutoStartFloating(enabled: Boolean) {
        viewModelScope.launch {
            preferencesManager.setAutoStartFloating(enabled)
        }
    }
    
    // Features
    fun setQuickTileEnabled(enabled: Boolean) {
        viewModelScope.launch {
            preferencesManager.setQuickTileEnabled(enabled)
        }
    }
    
    fun setNotificationEnabled(enabled: Boolean) {
        viewModelScope.launch {
            preferencesManager.setNotificationEnabled(enabled)
        }
    }
    
    fun setVoiceInputEnabled(enabled: Boolean) {
        viewModelScope.launch {
            preferencesManager.setVoiceInputEnabled(enabled)
        }
    }
    
    fun setFileUploadEnabled(enabled: Boolean) {
        viewModelScope.launch {
            preferencesManager.setFileUploadEnabled(enabled)
        }
    }
    
    fun setScreenshotEnabled(enabled: Boolean) {
        viewModelScope.launch {
            preferencesManager.setScreenshotEnabled(enabled)
        }
    }
    
    // Appearance
    fun setThemeMode(mode: String) {
        viewModelScope.launch {
            preferencesManager.setThemeMode(mode)
        }
    }
    
    fun setDynamicColor(enabled: Boolean) {
        viewModelScope.launch {
            preferencesManager.setDynamicColor(enabled)
        }
    }
    
    // API Keys
    fun setGeminiApiKey(key: String) {
        viewModelScope.launch {
            preferencesManager.setGeminiApiKey(key)
        }
    }
    
    fun setOpenaiApiKey(key: String) {
        viewModelScope.launch {
            preferencesManager.setOpenaiApiKey(key)
        }
    }
    
    fun setAnthropicApiKey(key: String) {
        viewModelScope.launch {
            preferencesManager.setAnthropicApiKey(key)
        }
    }
    
    // Privacy
    fun setAnalyticsEnabled(enabled: Boolean) {
        viewModelScope.launch {
            preferencesManager.setAnalyticsEnabled(enabled)
        }
    }
    
    // Utility
    fun updateOverlayPermission(hasPermission: Boolean) {
        _uiState.value = _uiState.value.copy(hasOverlayPermission = hasPermission)
    }
    
    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }
    
    fun resetToDefaults() {
        viewModelScope.launch {
            preferencesManager.resetToDefaults()
        }
    }
}
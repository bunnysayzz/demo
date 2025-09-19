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

data class MainUiState(
    val isLoading: Boolean = false,
    val selectedService: AIService = AIServices.chatGPT,
    val visibleServices: List<AIService> = AIServices.getVisibleServices(),
    val allServices: List<AIService> = AIServices.allServices,
    val themeMode: String = "system",
    val dynamicColor: Boolean = true,
    val alwaysOnTop: Boolean = false,
    val floatingWindowEnabled: Boolean = false,
    val hasOverlayPermission: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class MainViewModel @Inject constructor(
    private val preferencesManager: PreferencesManager
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(MainUiState())
    val uiState: StateFlow<MainUiState> = _uiState.asStateFlow()
    
    init {
        observePreferences()
    }
    
    private fun observePreferences() {
        viewModelScope.launch {
            // Combine all relevant preferences
            combine(
                preferencesManager.themeMode,
                preferencesManager.dynamicColor,
                preferencesManager.alwaysOnTop,
                preferencesManager.floatingWindowEnabled,
                preferencesManager.selectedServiceId,
                preferencesManager.allModelVisibility
            ) { themeMode, dynamicColor, alwaysOnTop, floatingWindowEnabled, selectedServiceId, modelVisibility ->
                
                val visibleServices = AIServices.allServices.filter { service ->
                    modelVisibility[service.id] ?: service.isVisible
                }
                
                val selectedService = AIServices.getServiceById(selectedServiceId) 
                    ?: visibleServices.firstOrNull() 
                    ?: AIServices.chatGPT
                
                MainUiState(
                    selectedService = selectedService,
                    visibleServices = visibleServices,
                    allServices = AIServices.allServices,
                    themeMode = themeMode,
                    dynamicColor = dynamicColor,
                    alwaysOnTop = alwaysOnTop,
                    floatingWindowEnabled = floatingWindowEnabled
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
    
    fun selectService(service: AIService) {
        viewModelScope.launch {
            preferencesManager.setSelectedServiceId(service.id)
        }
    }
    
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
    
    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }
    
    fun setLoading(loading: Boolean) {
        _uiState.value = _uiState.value.copy(isLoading = loading)
    }
    
    fun updateOverlayPermission(hasPermission: Boolean) {
        _uiState.value = _uiState.value.copy(hasOverlayPermission = hasPermission)
    }
}
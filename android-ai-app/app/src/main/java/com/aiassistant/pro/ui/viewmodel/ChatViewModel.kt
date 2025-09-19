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

data class ChatUiState(
    val isLoading: Boolean = false,
    val selectedService: AIService = AIServices.chatGPT,
    val availableServices: List<AIService> = AIServices.getVisibleServices(),
    val currentUrl: String = "",
    val canGoBack: Boolean = false,
    val canGoForward: Boolean = false,
    val error: String? = null,
    val isFileUploadActive: Boolean = false
)

@HiltViewModel
class ChatViewModel @Inject constructor(
    private val preferencesManager: PreferencesManager
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()
    
    init {
        observePreferences()
    }
    
    private fun observePreferences() {
        viewModelScope.launch {
            combine(
                preferencesManager.selectedServiceId,
                preferencesManager.allModelVisibility
            ) { selectedServiceId, modelVisibility ->
                
                val availableServices = AIServices.allServices.filter { service ->
                    modelVisibility[service.id] ?: service.isVisible
                }
                
                val selectedService = AIServices.getServiceById(selectedServiceId) 
                    ?: availableServices.firstOrNull() 
                    ?: AIServices.chatGPT
                
                ChatUiState(
                    selectedService = selectedService,
                    availableServices = availableServices,
                    currentUrl = selectedService.url
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
    
    fun setLoading(loading: Boolean) {
        _uiState.value = _uiState.value.copy(isLoading = loading)
    }
    
    fun updateCurrentUrl(url: String) {
        _uiState.value = _uiState.value.copy(currentUrl = url)
    }
    
    fun updateNavigationState(canGoBack: Boolean, canGoForward: Boolean) {
        _uiState.value = _uiState.value.copy(
            canGoBack = canGoBack,
            canGoForward = canGoForward
        )
    }
    
    fun triggerFileUpload() {
        if (_uiState.value.selectedService.supportsFileUpload) {
            _uiState.value = _uiState.value.copy(isFileUploadActive = true)
            // File upload logic would be implemented here
            // This would trigger the WebView's file input
        }
    }
    
    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }
    
    fun refreshWebView() {
        // This would trigger a refresh in the WebView
        setLoading(true)
    }
    
    fun goBack() {
        // This would trigger navigation back in the WebView
    }
    
    fun goForward() {
        // This would trigger navigation forward in the WebView
    }
    
    fun reloadPage() {
        // This would reload the current page in the WebView
        setLoading(true)
    }
}
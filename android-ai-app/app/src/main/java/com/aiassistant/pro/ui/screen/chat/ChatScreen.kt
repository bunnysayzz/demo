package com.aiassistant.pro.ui.screen.chat

import android.webkit.WebView
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.aiassistant.pro.data.model.AIServices
import com.aiassistant.pro.data.model.colorValue
import com.aiassistant.pro.ui.components.AIWebView
import com.aiassistant.pro.ui.components.ServiceSelector
import com.aiassistant.pro.ui.viewmodel.ChatViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    serviceId: String?,
    onNavigateBack: () -> Unit,
    viewModel: ChatViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    
    // Initialize with specific service if provided
    LaunchedEffect(serviceId) {
        serviceId?.let { id ->
            val service = AIServices.getServiceById(id)
            service?.let { viewModel.selectService(it) }
        }
    }
    
    var showServiceSelector by remember { mutableStateOf(false) }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // Top App Bar with Service Selection
        TopAppBar(
            title = {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    // Service indicator
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = uiState.selectedService.colorValue.copy(alpha = 0.15f),
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)
                        ) {
                            // Service icon placeholder
                            Box(
                                modifier = Modifier
                                    .size(20.dp)
                                    .background(
                                        color = uiState.selectedService.colorValue,
                                        shape = RoundedCornerShape(4.dp)
                                    )
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = uiState.selectedService.displayName,
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = uiState.selectedService.colorValue
                            )
                        }
                    }
                    
                    Spacer(modifier = Modifier.weight(1f))
                    
                    // Loading indicator
                    AnimatedVisibility(
                        visible = uiState.isLoading,
                        enter = fadeIn() + scaleIn(),
                        exit = fadeOut() + scaleOut()
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            strokeWidth = 2.dp,
                            color = uiState.selectedService.colorValue
                        )
                    }
                }
            },
            navigationIcon = {
                IconButton(onClick = onNavigateBack) {
                    Icon(
                        imageVector = Icons.Default.ArrowBack,
                        contentDescription = "Back"
                    )
                }
            },
            actions = {
                // Service selector button
                IconButton(
                    onClick = { showServiceSelector = true }
                ) {
                    Icon(
                        imageVector = Icons.Default.SwapHoriz,
                        contentDescription = "Switch Service",
                        tint = MaterialTheme.colorScheme.onSurface
                    )
                }
                
                // File upload button
                IconButton(
                    onClick = { viewModel.triggerFileUpload() },
                    enabled = uiState.selectedService.supportsFileUpload
                ) {
                    Icon(
                        imageVector = Icons.Default.AttachFile,
                        contentDescription = "Upload File",
                        tint = if (uiState.selectedService.supportsFileUpload) {
                            MaterialTheme.colorScheme.onSurface
                        } else {
                            MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
                        }
                    )
                }
                
                // More options
                IconButton(
                    onClick = { /* Show more options */ }
                ) {
                    Icon(
                        imageVector = Icons.Default.MoreVert,
                        contentDescription = "More Options"
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = MaterialTheme.colorScheme.surface,
                titleContentColor = MaterialTheme.colorScheme.onSurface,
                navigationIconContentColor = MaterialTheme.colorScheme.onSurface,
                actionIconContentColor = MaterialTheme.colorScheme.onSurface
            )
        )
        
        // Service indicator bar
        Surface(
            modifier = Modifier.fillMaxWidth(),
            color = uiState.selectedService.colorValue.copy(alpha = 0.1f)
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = uiState.selectedService.description.ifEmpty { "AI Assistant" },
                    style = MaterialTheme.typography.bodySmall,
                    color = uiState.selectedService.colorValue,
                    modifier = Modifier.weight(1f)
                )
                
                // Feature indicators
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    if (uiState.selectedService.supportsVoice) {
                        Icon(
                            imageVector = Icons.Default.Mic,
                            contentDescription = "Voice support",
                            tint = uiState.selectedService.colorValue,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                    if (uiState.selectedService.supportsFileUpload) {
                        Icon(
                            imageVector = Icons.Default.AttachFile,
                            contentDescription = "File upload",
                            tint = uiState.selectedService.colorValue,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }
        }
        
        // WebView
        AIWebView(
            service = uiState.selectedService,
            onLoadingChanged = { isLoading ->
                viewModel.setLoading(isLoading)
            },
            onUrlChanged = { url ->
                viewModel.updateCurrentUrl(url)
            },
            modifier = Modifier
                .fillMaxSize()
                .weight(1f)
        )
    }
    
    // Service Selector Bottom Sheet
    if (showServiceSelector) {
        ServiceSelector(
            services = uiState.availableServices,
            selectedService = uiState.selectedService,
            onServiceSelected = { service ->
                viewModel.selectService(service)
                showServiceSelector = false
            },
            onDismiss = { showServiceSelector = false }
        )
    }
    
    // Handle error states
    uiState.error?.let { error ->
        LaunchedEffect(error) {
            // Show error snackbar or dialog
        }
    }
}
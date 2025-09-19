package com.aiassistant.pro.ui.screen.settings

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.aiassistant.pro.ui.components.ModelVisibilityGrid
import com.aiassistant.pro.ui.components.SettingsCard
import com.aiassistant.pro.ui.components.SettingsSection
import com.aiassistant.pro.ui.components.ApiKeySection
import com.aiassistant.pro.ui.viewmodel.SettingsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onNavigateBack: () -> Unit,
    onRequestOverlayPermission: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    
    Column(
        modifier = Modifier.fillMaxSize()
    ) {
        // Top App Bar
        TopAppBar(
            title = {
                Text(
                    text = "Settings",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
            },
            navigationIcon = {
                IconButton(onClick = onNavigateBack) {
                    Icon(
                        imageVector = Icons.Default.ArrowBack,
                        contentDescription = "Back"
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = MaterialTheme.colorScheme.surface,
                titleContentColor = MaterialTheme.colorScheme.onSurface,
                navigationIconContentColor = MaterialTheme.colorScheme.onSurface
            )
        )
        
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // General Settings Section
            item {
                SettingsSection(
                    title = "General",
                    icon = Icons.Default.Settings
                ) {
                    GeneralSettingsContent(
                        uiState = uiState,
                        viewModel = viewModel,
                        onRequestOverlayPermission = onRequestOverlayPermission
                    )
                }
            }
            
            // AI Models Section
            item {
                SettingsSection(
                    title = "AI Models",
                    icon = Icons.Default.SmartToy,
                    action = {
                        TextButton(
                            onClick = { viewModel.resetModelVisibilityToDefaults() }
                        ) {
                            Text("Reset All")
                        }
                    }
                ) {
                    ModelVisibilityGrid(
                        services = uiState.allServices,
                        modelVisibility = uiState.modelVisibility,
                        onModelVisibilityChanged = { serviceId, visible ->
                            viewModel.setModelVisibility(serviceId, visible)
                        }
                    )
                }
            }
            
            // Features Section
            item {
                SettingsSection(
                    title = "Features",
                    icon = Icons.Default.Extension
                ) {
                    FeaturesSettingsContent(
                        uiState = uiState,
                        viewModel = viewModel
                    )
                }
            }
            
            // API Keys Section
            item {
                SettingsSection(
                    title = "API Keys",
                    icon = Icons.Default.Key
                ) {
                    ApiKeySection(
                        geminiApiKey = uiState.geminiApiKey,
                        openaiApiKey = uiState.openaiApiKey,
                        onGeminiApiKeyChanged = { viewModel.setGeminiApiKey(it) },
                        onOpenaiApiKeyChanged = { viewModel.setOpenaiApiKey(it) }
                    )
                }
            }
            
            // Appearance Section
            item {
                SettingsSection(
                    title = "Appearance",
                    icon = Icons.Default.Palette
                ) {
                    AppearanceSettingsContent(
                        uiState = uiState,
                        viewModel = viewModel
                    )
                }
            }
            
            // Privacy Section
            item {
                SettingsSection(
                    title = "Privacy",
                    icon = Icons.Default.Security
                ) {
                    PrivacySettingsContent(
                        uiState = uiState,
                        viewModel = viewModel
                    )
                }
            }
            
            // About Section
            item {
                SettingsSection(
                    title = "About",
                    icon = Icons.Default.Info
                ) {
                    AboutSettingsContent()
                }
            }
        }
    }
}

@Composable
private fun GeneralSettingsContent(
    uiState: com.aiassistant.pro.ui.viewmodel.SettingsUiState,
    viewModel: SettingsViewModel,
    onRequestOverlayPermission: () -> Unit
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Always on Top
        SettingsCard(
            title = "Always on Top",
            description = "Keep the app window above other apps",
            icon = Icons.Default.PinDrop,
            trailing = {
                Switch(
                    checked = uiState.alwaysOnTop,
                    onCheckedChange = { viewModel.setAlwaysOnTop(it) }
                )
            }
        )
        
        // Floating Window
        SettingsCard(
            title = "Floating Window",
            description = if (uiState.hasOverlayPermission) {
                "Show AI assistant in a floating window"
            } else {
                "Requires overlay permission"
            },
            icon = Icons.Default.PictureInPicture,
            trailing = {
                Switch(
                    checked = uiState.floatingWindowEnabled,
                    onCheckedChange = { enabled ->
                        if (enabled && !uiState.hasOverlayPermission) {
                            onRequestOverlayPermission()
                        } else {
                            viewModel.setFloatingWindowEnabled(enabled)
                        }
                    },
                    enabled = uiState.hasOverlayPermission
                )
            }
        )
        
        // Auto Start Floating
        AnimatedVisibility(
            visible = uiState.floatingWindowEnabled && uiState.hasOverlayPermission,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            SettingsCard(
                title = "Auto Start Floating Window",
                description = "Automatically show floating window on app start",
                icon = Icons.Default.AutoAwesome,
                trailing = {
                    Switch(
                        checked = uiState.autoStartFloating,
                        onCheckedChange = { viewModel.setAutoStartFloating(it) }
                    )
                }
            )
        }
        
        // Quick Settings Tile
        SettingsCard(
            title = "Quick Settings Tile",
            description = "Add tile to Quick Settings panel",
            icon = Icons.Default.Widgets,
            trailing = {
                Switch(
                    checked = uiState.quickTileEnabled,
                    onCheckedChange = { viewModel.setQuickTileEnabled(it) }
                )
            }
        )
    }
}

@Composable
private fun FeaturesSettingsContent(
    uiState: com.aiassistant.pro.ui.viewmodel.SettingsUiState,
    viewModel: SettingsViewModel
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Voice Input
        SettingsCard(
            title = "Voice Input",
            description = "Enable voice input for supported AI services",
            icon = Icons.Default.Mic,
            trailing = {
                Switch(
                    checked = uiState.voiceInputEnabled,
                    onCheckedChange = { viewModel.setVoiceInputEnabled(it) }
                )
            }
        )
        
        // File Upload
        SettingsCard(
            title = "File Upload",
            description = "Allow file uploads to AI services",
            icon = Icons.Default.AttachFile,
            trailing = {
                Switch(
                    checked = uiState.fileUploadEnabled,
                    onCheckedChange = { viewModel.setFileUploadEnabled(it) }
                )
            }
        )
        
        // Screenshot
        SettingsCard(
            title = "Screenshot Capture",
            description = "Enable screenshot capture functionality",
            icon = Icons.Default.Screenshot,
            trailing = {
                Switch(
                    checked = uiState.screenshotEnabled,
                    onCheckedChange = { viewModel.setScreenshotEnabled(it) }
                )
            }
        )
        
        // Notifications
        SettingsCard(
            title = "Notifications",
            description = "Show notifications for important events",
            icon = Icons.Default.Notifications,
            trailing = {
                Switch(
                    checked = uiState.notificationEnabled,
                    onCheckedChange = { viewModel.setNotificationEnabled(it) }
                )
            }
        )
    }
}

@Composable
private fun AppearanceSettingsContent(
    uiState: com.aiassistant.pro.ui.viewmodel.SettingsUiState,
    viewModel: SettingsViewModel
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Theme Mode
        SettingsCard(
            title = "Theme",
            description = "Choose your preferred theme",
            icon = Icons.Default.DarkMode,
            onClick = {
                // Show theme selector
            }
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                ThemeOption(
                    text = "Light",
                    selected = uiState.themeMode == "light",
                    onClick = { viewModel.setThemeMode("light") }
                )
                ThemeOption(
                    text = "Dark",
                    selected = uiState.themeMode == "dark",
                    onClick = { viewModel.setThemeMode("dark") }
                )
                ThemeOption(
                    text = "System",
                    selected = uiState.themeMode == "system",
                    onClick = { viewModel.setThemeMode("system") }
                )
            }
        }
        
        // Dynamic Color
        SettingsCard(
            title = "Dynamic Color",
            description = "Use system accent color (Android 12+)",
            icon = Icons.Default.Palette,
            trailing = {
                Switch(
                    checked = uiState.dynamicColor,
                    onCheckedChange = { viewModel.setDynamicColor(it) }
                )
            }
        )
    }
}

@Composable
private fun PrivacySettingsContent(
    uiState: com.aiassistant.pro.ui.viewmodel.SettingsUiState,
    viewModel: SettingsViewModel
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Analytics
        SettingsCard(
            title = "Analytics",
            description = "Help improve the app by sharing usage data",
            icon = Icons.Default.Analytics,
            trailing = {
                Switch(
                    checked = uiState.analyticsEnabled,
                    onCheckedChange = { viewModel.setAnalyticsEnabled(it) }
                )
            }
        )
        
        // Privacy Notice
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f)
            )
        ) {
            Column(
                modifier = Modifier.padding(16.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Security,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = "Privacy First",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "We don't collect your chats or personal data. All AI interactions go directly to the respective service providers.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
        }
    }
}

@Composable
private fun AboutSettingsContent() {
    Column(
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // App Version
        SettingsCard(
            title = "AI Assistant Pro",
            description = "Version 1.0.0",
            icon = Icons.Default.Info
        )
        
        // Links
        SettingsCard(
            title = "GitHub",
            description = "View source code and contribute",
            icon = Icons.Default.Code,
            onClick = {
                // Open GitHub link
            }
        )
        
        SettingsCard(
            title = "Privacy Policy",
            description = "Read our privacy policy",
            icon = Icons.Default.PrivacyTip,
            onClick = {
                // Open privacy policy
            }
        )
        
        SettingsCard(
            title = "Terms of Service",
            description = "Read our terms of service",
            icon = Icons.Default.Description,
            onClick = {
                // Open terms of service
            }
        )
    }
}

@Composable
private fun ThemeOption(
    text: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    FilterChip(
        onClick = onClick,
        label = { Text(text) },
        selected = selected,
        leadingIcon = if (selected) {
            {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
            }
        } else null
    )
}
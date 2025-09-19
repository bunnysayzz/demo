package com.aiassistant.pro.service

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.*
import android.widget.Toast
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.unit.dp
import androidx.core.app.NotificationCompat
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.aiassistant.pro.AIAssistantApplication
import com.aiassistant.pro.R
import com.aiassistant.pro.data.model.AIServices
import com.aiassistant.pro.data.preferences.PreferencesManager
import com.aiassistant.pro.ui.components.AIWebView
import com.aiassistant.pro.ui.components.ServiceSelector
import com.aiassistant.pro.ui.theme.AIAssistantProTheme
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import javax.inject.Inject

@AndroidEntryPoint
class FloatingWindowService : Service(), ViewModelStoreOwner, SavedStateRegistryOwner {
    
    @Inject
    lateinit var preferencesManager: PreferencesManager
    
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var isFloatingWindowVisible = false
    
    // ViewModelStore and SavedStateRegistry for Compose
    private val _viewModelStore = ViewModelStore()
    override val viewModelStore: ViewModelStore get() = _viewModelStore
    
    private val savedStateRegistryController = SavedStateRegistryController.create(this)
    override val savedStateRegistry: SavedStateRegistry = savedStateRegistryController.savedStateRegistry
    
    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val WINDOW_WIDTH = 350
        private const val WINDOW_HEIGHT = 500
        
        fun startService(context: Context) {
            val intent = Intent(context, FloatingWindowService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stopService(context: Context) {
            val intent = Intent(context, FloatingWindowService::class.java)
            context.stopService(intent)
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        savedStateRegistryController.performRestore(null)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                Toast.makeText(this, "Overlay permission required", Toast.LENGTH_SHORT).show()
                stopSelf()
                return
            }
        }
        
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createFloatingWindow()
        startForegroundService()
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        removeFloatingWindow()
        _viewModelStore.clear()
    }
    
    private fun startForegroundService() {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
    }
    
    private fun createNotification(): Notification {
        val notificationIntent = Intent(this, com.aiassistant.pro.ui.MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, AIAssistantApplication.FLOATING_WINDOW_CHANNEL_ID)
            .setContentTitle("AI Assistant Pro")
            .setContentText("Floating window is active")
            .setSmallIcon(R.drawable.ic_ai_assistant)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
    
    private fun createFloatingWindow() {
        val layoutParams = WindowManager.LayoutParams().apply {
            width = dpToPx(WINDOW_WIDTH)
            height = dpToPx(WINDOW_HEIGHT)
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
            format = PixelFormat.TRANSLUCENT
            gravity = Gravity.TOP or Gravity.START
            x = 100
            y = 100
        }
        
        // Create ComposeView for floating window
        val composeView = ComposeView(this).apply {
            setViewTreeViewModelStoreOwner(this@FloatingWindowService)
            setViewTreeSavedStateRegistryOwner(this@FloatingWindowService)
            
            setContent {
                FloatingWindowContent(
                    onClose = { removeFloatingWindow() },
                    onMinimize = { minimizeWindow() },
                    onExpand = { expandWindow() }
                )
            }
        }
        
        floatingView = composeView
        
        try {
            windowManager?.addView(composeView, layoutParams)
            isFloatingWindowVisible = true
        } catch (e: Exception) {
            e.printStackTrace()
            Toast.makeText(this, "Failed to create floating window", Toast.LENGTH_SHORT).show()
            stopSelf()
        }
    }
    
    @Composable
    private fun FloatingWindowContent(
        onClose: () -> Unit,
        onMinimize: () -> Unit,
        onExpand: () -> Unit
    ) {
        var isMinimized by remember { mutableStateOf(false) }
        var showServiceSelector by remember { mutableStateOf(false) }
        
        // Get current service from preferences
        val selectedServiceId by remember {
            runBlocking { preferencesManager.selectedServiceId.first() }
        }.let { mutableStateOf(it) }
        
        val selectedService = AIServices.getServiceById(selectedServiceId) ?: AIServices.chatGPT
        val visibleServices = AIServices.getVisibleServices()
        
        AIAssistantProTheme {
            Surface(
                modifier = Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(12.dp)),
                color = MaterialTheme.colorScheme.surface,
                shadowElevation = 8.dp
            ) {
                if (isMinimized) {
                    // Minimized state - compact floating button
                    MinimizedFloatingWindow(
                        service = selectedService,
                        onExpand = {
                            isMinimized = false
                            onExpand()
                        },
                        onClose = onClose
                    )
                } else {
                    // Expanded state - full floating window
                    Column(
                        modifier = Modifier.fillMaxSize()
                    ) {
                        // Title bar
                        FloatingWindowTitleBar(
                            service = selectedService,
                            onClose = onClose,
                            onMinimize = {
                                isMinimized = true
                                onMinimize()
                            },
                            onServiceSelectorClick = {
                                showServiceSelector = true
                            }
                        )
                        
                        // WebView content
                        AIWebView(
                            service = selectedService,
                            onLoadingChanged = { /* Handle loading state */ },
                            onUrlChanged = { /* Handle URL changes */ },
                            modifier = Modifier
                                .fillMaxSize()
                                .weight(1f)
                        )
                    }
                }
            }
            
            // Service selector
            if (showServiceSelector) {
                ServiceSelector(
                    services = visibleServices,
                    selectedService = selectedService,
                    onServiceSelected = { service ->
                        runBlocking {
                            preferencesManager.setSelectedServiceId(service.id)
                        }
                        showServiceSelector = false
                    },
                    onDismiss = { showServiceSelector = false }
                )
            }
        }
    }
    
    @Composable
    private fun FloatingWindowTitleBar(
        service: com.aiassistant.pro.data.model.AIService,
        onClose: () -> Unit,
        onMinimize: () -> Unit,
        onServiceSelectorClick: () -> Unit
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            color = service.colorValue.copy(alpha = 0.1f)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Service info
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    Box(
                        modifier = Modifier
                            .size(24.dp)
                            .background(
                                color = service.colorValue,
                                shape = RoundedCornerShape(4.dp)
                            )
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = service.displayName,
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
                
                // Control buttons
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    IconButton(
                        onClick = onServiceSelectorClick,
                        modifier = Modifier.size(32.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.SwapHoriz,
                            contentDescription = "Switch Service",
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.onSurface
                        )
                    }
                    
                    IconButton(
                        onClick = onMinimize,
                        modifier = Modifier.size(32.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Minimize,
                            contentDescription = "Minimize",
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.onSurface
                        )
                    }
                    
                    IconButton(
                        onClick = onClose,
                        modifier = Modifier.size(32.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Close",
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.error
                        )
                    }
                }
            }
        }
    }
    
    @Composable
    private fun MinimizedFloatingWindow(
        service: com.aiassistant.pro.data.model.AIService,
        onExpand: () -> Unit,
        onClose: () -> Unit
    ) {
        Surface(
            modifier = Modifier
                .size(56.dp)
                .clip(RoundedCornerShape(28.dp)),
            color = service.colorValue,
            shadowElevation = 8.dp,
            onClick = onExpand
        ) {
            Box(
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.SmartToy,
                    contentDescription = "Expand AI Assistant",
                    tint = Color.White,
                    modifier = Modifier.size(24.dp)
                )
            }
        }
    }
    
    private fun removeFloatingWindow() {
        floatingView?.let { view ->
            try {
                windowManager?.removeView(view)
                isFloatingWindowVisible = false
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        floatingView = null
        stopSelf()
    }
    
    private fun minimizeWindow() {
        floatingView?.let { view ->
            val layoutParams = view.layoutParams as WindowManager.LayoutParams
            layoutParams.width = dpToPx(56)
            layoutParams.height = dpToPx(56)
            windowManager?.updateViewLayout(view, layoutParams)
        }
    }
    
    private fun expandWindow() {
        floatingView?.let { view ->
            val layoutParams = view.layoutParams as WindowManager.LayoutParams
            layoutParams.width = dpToPx(WINDOW_WIDTH)
            layoutParams.height = dpToPx(WINDOW_HEIGHT)
            windowManager?.updateViewLayout(view, layoutParams)
        }
    }
    
    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }
}
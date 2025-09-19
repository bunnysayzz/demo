package com.aiassistant.pro.service

import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import com.aiassistant.pro.R
import com.aiassistant.pro.ui.MainActivity
import dagger.hilt.android.AndroidEntryPoint

@RequiresApi(Build.VERSION_CODES.N)
@AndroidEntryPoint
class AIAssistantTileService : TileService() {
    
    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }
    
    override fun onClick() {
        super.onClick()
        
        // Check if floating window service is running
        val isFloatingWindowActive = isFloatingWindowServiceRunning()
        
        if (isFloatingWindowActive) {
            // Stop floating window service
            FloatingWindowService.stopService(this)
        } else {
            // Check overlay permission and start floating window or main app
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (android.provider.Settings.canDrawOverlays(this)) {
                    FloatingWindowService.startService(this)
                } else {
                    // Open main app to request permission
                    openMainApp()
                }
            } else {
                FloatingWindowService.startService(this)
            }
        }
        
        updateTile()
    }
    
    private fun updateTile() {
        val tile = qsTile ?: return
        val isFloatingWindowActive = isFloatingWindowServiceRunning()
        
        tile.apply {
            state = if (isFloatingWindowActive) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            label = "AI Assistant"
            contentDescription = if (isFloatingWindowActive) {
                "AI Assistant is active - tap to close"
            } else {
                "AI Assistant - tap to open floating window"
            }
            
            // Update icon based on state
            icon = if (isFloatingWindowActive) {
                Icon.createWithResource(this@AIAssistantTileService, R.drawable.ic_ai_assistant_active)
            } else {
                Icon.createWithResource(this@AIAssistantTileService, R.drawable.ic_ai_assistant)
            }
        }
        
        tile.updateTile()
    }
    
    private fun isFloatingWindowServiceRunning(): Boolean {
        val activityManager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
        val runningServices = activityManager.getRunningServices(Integer.MAX_VALUE)
        
        return runningServices.any { serviceInfo ->
            serviceInfo.service.className == FloatingWindowService::class.java.name
        }
    }
    
    private fun openMainApp() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        startActivityAndCollapse(intent)
    }
}
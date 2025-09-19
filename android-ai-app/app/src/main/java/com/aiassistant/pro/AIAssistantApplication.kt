package com.aiassistant.pro

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class AIAssistantApplication : Application() {
    
    companion object {
        const val FLOATING_WINDOW_CHANNEL_ID = "floating_window_channel"
        const val SCREENSHOT_CHANNEL_ID = "screenshot_channel"
        const val GENERAL_CHANNEL_ID = "general_channel"
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }
    
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Floating window channel
            val floatingChannel = NotificationChannel(
                FLOATING_WINDOW_CHANNEL_ID,
                "Floating Window",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notifications for floating window service"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
            }
            
            // Screenshot channel
            val screenshotChannel = NotificationChannel(
                SCREENSHOT_CHANNEL_ID,
                "Screenshots",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Screenshot capture notifications"
                setShowBadge(true)
            }
            
            // General channel
            val generalChannel = NotificationChannel(
                GENERAL_CHANNEL_ID,
                "General",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "General app notifications"
                setShowBadge(true)
            }
            
            notificationManager.createNotificationChannels(
                listOf(floatingChannel, screenshotChannel, generalChannel)
            )
        }
    }
}
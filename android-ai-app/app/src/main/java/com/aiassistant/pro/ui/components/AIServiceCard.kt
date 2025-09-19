package com.aiassistant.pro.ui.components

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.aiassistant.pro.data.model.AIService
import com.aiassistant.pro.data.model.colorValue

@Composable
fun AIServiceCard(
    service: AIService,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    var isPressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.95f else 1f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "scale"
    )
    
    val elevation by animateDpAsState(
        targetValue = if (isSelected) 8.dp else 2.dp,
        animationSpec = tween(300),
        label = "elevation"
    )
    
    Card(
        modifier = modifier
            .scale(scale)
            .clickable {
                onClick()
            }
            .fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = elevation),
        colors = CardDefaults.cardColors(
            containerColor = if (isSelected) {
                service.colorValue.copy(alpha = 0.1f)
            } else {
                MaterialTheme.colorScheme.surface
            }
        ),
        border = if (isSelected) {
            androidx.compose.foundation.BorderStroke(
                width = 2.dp,
                color = service.colorValue
            )
        } else null
    ) {
        Column(
            modifier = Modifier
                .padding(16.dp)
                .fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Service Icon
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(
                        brush = Brush.radialGradient(
                            colors = listOf(
                                service.colorValue.copy(alpha = 0.2f),
                                service.colorValue.copy(alpha = 0.05f)
                            )
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                // Try to load icon from resources, fallback to default icon
                val iconResourceId = remember(service.iconResource) {
                    try {
                        // This would need proper resource mapping
                        getIconResourceId(service.iconResource)
                    } catch (e: Exception) {
                        null
                    }
                }
                
                if (iconResourceId != null) {
                    AsyncImage(
                        model = ImageRequest.Builder(LocalContext.current)
                            .data(iconResourceId)
                            .crossfade(true)
                            .build(),
                        contentDescription = "${service.name} icon",
                        modifier = Modifier.size(24.dp)
                    )
                } else {
                    // Fallback icon based on category
                    Icon(
                        imageVector = when (service.category) {
                            com.aiassistant.pro.data.model.AIServiceCategory.CODING -> Icons.Default.Code
                            com.aiassistant.pro.data.model.AIServiceCategory.CREATIVE -> Icons.Default.Palette
                            com.aiassistant.pro.data.model.AIServiceCategory.RESEARCH -> Icons.Default.Search
                            com.aiassistant.pro.data.model.AIServiceCategory.CUSTOM -> Icons.Default.Settings
                            else -> Icons.Default.SmartToy
                        },
                        contentDescription = "${service.name} icon",
                        tint = service.colorValue,
                        modifier = Modifier.size(24.dp)
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(12.dp))
            
            // Service Name
            Text(
                text = service.displayName,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = if (isSelected) service.colorValue else MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            
            Spacer(modifier = Modifier.height(4.dp))
            
            // Service Description
            Text(
                text = service.description.ifEmpty { "AI Assistant" },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                lineHeight = MaterialTheme.typography.bodySmall.lineHeight
            )
            
            // Features badges
            if (service.features.isNotEmpty()) {
                Spacer(modifier = Modifier.height(8.dp))
                
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    service.features.take(2).forEach { feature ->
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = service.colorValue.copy(alpha = 0.1f),
                            modifier = Modifier.weight(1f, fill = false)
                        ) {
                            Text(
                                text = feature,
                                style = MaterialTheme.typography.labelSmall,
                                color = service.colorValue,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }
            }
            
            // Status indicators
            if (service.supportsVoice || service.supportsFileUpload) {
                Spacer(modifier = Modifier.height(8.dp))
                
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    if (service.supportsVoice) {
                        Icon(
                            imageVector = Icons.Default.Mic,
                            contentDescription = "Voice support",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                    if (service.supportsFileUpload) {
                        Icon(
                            imageVector = Icons.Default.AttachFile,
                            contentDescription = "File upload support",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }
        }
    }
}

// Helper function to map icon resource names to actual resource IDs
private fun getIconResourceId(iconResource: String): Int? {
    // This would need to be implemented based on your actual icon resources
    // For now, return null to use fallback icons
    return null
}
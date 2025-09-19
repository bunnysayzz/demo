package com.example.notesapp.ui.components

import androidx.compose.animation.*
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SwipeToDeleteContainer(
    item: Any,
    onDelete: () -> Unit,
    animationDuration: Int = 500,
    content: @Composable (Any) -> Unit
) {
    var isRemoved by remember { mutableStateOf(false) }
    val state = rememberDismissState(
        confirmValueChange = { value ->
            if (value == DismissValue.DismissedToStart) {
                isRemoved = true
                onDelete()
                true
            } else {
                false
            }
        }
    )

    LaunchedEffect(key1 = isRemoved) {
        if (isRemoved) {
            kotlinx.coroutines.delay(animationDuration.toLong())
        }
    }

    AnimatedVisibility(
        visible = !isRemoved,
        exit = androidx.compose.animation.shrinkVertically(
            animationSpec = androidx.compose.animation.core.tween(durationMillis = animationDuration),
            shrinkTowards = Alignment.Top
        ) + androidx.compose.animation.fadeOut()
    ) {
        SwipeToDismiss(
            state = state,
            modifier = Modifier.padding(vertical = 4.dp),
            directions = setOf(DismissDirection.EndToStart),
            background = {
                DeleteBackground(dismissState = state)
            },
            dismissContent = {
                content(item)
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeleteBackground(dismissState: DismissState) {
    val color by animateColorAsState(
        when (dismissState.targetValue) {
            DismissValue.Default -> MaterialTheme.colorScheme.surface
            DismissValue.DismissedToStart -> Color.Red
            else -> MaterialTheme.colorScheme.surface
        }, label = "color"
    )
    
    val scale by animateFloatAsState(
        if (dismissState.targetValue == DismissValue.Default) 0.75f else 1f, label = "scale"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(color)
            .padding(horizontal = 20.dp),
        contentAlignment = Alignment.CenterEnd
    ) {
        Icon(
            Icons.Default.Delete,
            contentDescription = "Delete",
            modifier = Modifier.scale(scale),
            tint = Color.White
        )
    }
}
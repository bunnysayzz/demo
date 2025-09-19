package com.aiassistant.pro.ui.navigation

import android.content.Intent
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.aiassistant.pro.ui.screen.chat.ChatScreen
import com.aiassistant.pro.ui.screen.home.HomeScreen
import com.aiassistant.pro.ui.screen.settings.SettingsScreen
import com.aiassistant.pro.ui.components.BottomNavigationBar
import com.aiassistant.pro.ui.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AIAssistantNavigation(
    onRequestOverlayPermission: () -> Unit,
    hasOverlayPermission: Boolean,
    onHandleSharedContent: (Intent) -> Unit,
    navController: NavHostController = rememberNavController(),
    viewModel: MainViewModel = hiltViewModel()
) {
    val currentBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = currentBackStackEntry?.destination
    
    // Update overlay permission status
    LaunchedEffect(hasOverlayPermission) {
        viewModel.updateOverlayPermission(hasOverlayPermission)
    }
    
    Scaffold(
        bottomBar = {
            BottomNavigationBar(
                currentDestination = currentDestination,
                onNavigate = { route ->
                    navController.navigate(route) {
                        // Pop up to the start destination of the graph to
                        // avoid building up a large stack of destinations
                        popUpTo(navController.graph.startDestinationId) {
                            saveState = true
                        }
                        // Avoid multiple copies of the same destination when
                        // reselecting the same item
                        launchSingleTop = true
                        // Restore state when reselecting a previously selected item
                        restoreState = true
                    }
                }
            )
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Screen.Home.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable(Screen.Home.route) {
                HomeScreen(
                    onNavigateToChat = { serviceId ->
                        navController.navigate(Screen.Chat.createRoute(serviceId))
                    },
                    onRequestOverlayPermission = onRequestOverlayPermission
                )
            }
            
            composable(
                route = Screen.Chat.route,
                arguments = Screen.Chat.arguments
            ) { backStackEntry ->
                val serviceId = backStackEntry.arguments?.getString("serviceId")
                ChatScreen(
                    serviceId = serviceId,
                    onNavigateBack = {
                        navController.popBackStack()
                    }
                )
            }
            
            composable(Screen.Settings.route) {
                SettingsScreen(
                    onNavigateBack = {
                        navController.popBackStack()
                    },
                    onRequestOverlayPermission = onRequestOverlayPermission
                )
            }
        }
    }
}
package com.aiassistant.pro.ui.navigation

import androidx.navigation.NamedNavArgument
import androidx.navigation.NavType
import androidx.navigation.navArgument

sealed class Screen(
    val route: String,
    val arguments: List<NamedNavArgument> = emptyList()
) {
    object Home : Screen("home")
    
    object Chat : Screen(
        route = "chat/{serviceId}",
        arguments = listOf(
            navArgument("serviceId") {
                type = NavType.StringType
                nullable = true
                defaultValue = null
            }
        )
    ) {
        fun createRoute(serviceId: String? = null): String {
            return if (serviceId != null) {
                "chat/$serviceId"
            } else {
                "chat/null"
            }
        }
    }
    
    object Settings : Screen("settings")
    
    object FloatingWindow : Screen("floating_window")
}
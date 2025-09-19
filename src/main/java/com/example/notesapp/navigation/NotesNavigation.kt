package com.example.notesapp.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.example.notesapp.ui.screens.AddEditNoteScreen
import com.example.notesapp.ui.screens.NotesListScreen

@Composable
fun NotesNavigation(
    navController: NavHostController = rememberNavController()
) {
    NavHost(
        navController = navController,
        startDestination = "notes_list"
    ) {
        composable("notes_list") {
            NotesListScreen(
                onNoteClick = { noteId ->
                    navController.navigate("add_edit_note/$noteId")
                },
                onAddNoteClick = {
                    navController.navigate("add_edit_note/0")
                }
            )
        }
        
        composable("add_edit_note/{noteId}") { backStackEntry ->
            val noteIdString = backStackEntry.arguments?.getString("noteId") ?: "0"
            val noteId = noteIdString.toLongOrNull()
            val actualNoteId = if (noteId == 0L) null else noteId
            
            AddEditNoteScreen(
                noteId = actualNoteId,
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }
    }
}
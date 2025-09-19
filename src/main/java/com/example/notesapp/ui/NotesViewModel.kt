package com.example.notesapp.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.notesapp.data.Note
import com.example.notesapp.repository.NotesRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.util.Date
import javax.inject.Inject

data class NotesUiState(
    val notes: List<Note> = emptyList(),
    val searchQuery: String = "",
    val isLoading: Boolean = false,
    val recentlyDeletedNote: Note? = null
)

@HiltViewModel
class NotesViewModel @Inject constructor(
    private val repository: NotesRepository
) : ViewModel() {

    private val _searchQuery = MutableStateFlow("")
    private val searchQuery = _searchQuery.asStateFlow()

    private val _recentlyDeletedNote = MutableStateFlow<Note?>(null)

    val uiState: StateFlow<NotesUiState> = combine(
        searchQuery,
        _recentlyDeletedNote
    ) { query, deletedNote ->
        Triple(query, deletedNote, if (query.isEmpty()) repository.getAllNotes() else repository.searchNotes(query))
    }.flatMapLatest { (query, deletedNote, notesFlow) ->
        notesFlow.map { notes ->
            NotesUiState(
                notes = notes,
                searchQuery = query,
                recentlyDeletedNote = deletedNote
            )
        }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = NotesUiState(isLoading = true)
    )

    fun updateSearchQuery(query: String) {
        _searchQuery.value = query
    }

    fun addNote(title: String, body: String) {
        viewModelScope.launch {
            val note = Note(
                title = title,
                body = body,
                createdAt = Date(),
                updatedAt = Date()
            )
            repository.insertNote(note)
        }
    }

    fun updateNote(id: Long, title: String, body: String) {
        viewModelScope.launch {
            val existingNote = repository.getNoteById(id)
            existingNote?.let { note ->
                val updatedNote = note.copy(
                    title = title,
                    body = body,
                    updatedAt = Date()
                )
                repository.updateNote(updatedNote)
            }
        }
    }

    fun deleteNote(note: Note) {
        viewModelScope.launch {
            repository.deleteNote(note)
            _recentlyDeletedNote.value = note
        }
    }

    fun restoreNote() {
        viewModelScope.launch {
            _recentlyDeletedNote.value?.let { note ->
                repository.insertNote(note)
                _recentlyDeletedNote.value = null
            }
        }
    }

    fun clearRecentlyDeletedNote() {
        _recentlyDeletedNote.value = null
    }
}
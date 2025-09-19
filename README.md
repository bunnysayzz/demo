# Notes App - Kotlin with Jetpack Compose

A modern, feature-rich notes application built with Kotlin and Jetpack Compose, featuring local storage with Room database and intuitive user interactions.

## Features

### ✨ Core Functionality
- **Add Notes**: Create new notes with title and body content
- **Edit Notes**: Modify existing notes seamlessly
- **View Notes**: Browse all notes in a clean, organized list
- **Search Notes**: Real-time search through note titles and content
- **Swipe to Delete**: Intuitive gesture-based note deletion
- **Undo Deletion**: Restore accidentally deleted notes with Snackbar

### 🏗️ Technical Architecture
- **Jetpack Compose**: Modern declarative UI toolkit
- **Room Database**: Local SQLite database with type-safe queries
- **Hilt**: Dependency injection for clean architecture
- **MVVM Pattern**: Separation of concerns with ViewModel
- **Kotlin Coroutines**: Asynchronous programming with Flow
- **Material 3**: Latest Material Design components

### 📱 User Experience
- **Responsive Design**: Adapts to different screen sizes
- **Dark/Light Theme**: System-based theme switching
- **Smooth Animations**: Polished transitions and interactions
- **Intuitive Navigation**: Easy-to-use navigation between screens
- **Empty States**: Helpful guidance when no notes exist
- **Real-time Updates**: Instant UI updates with reactive programming

## Project Structure

```
src/main/java/com/example/notesapp/
├── data/
│   ├── Note.kt              # Room entity
│   ├── NoteDao.kt           # Database access object
│   ├── NotesDatabase.kt     # Room database
│   └── Converters.kt        # Type converters for Room
├── repository/
│   └── NotesRepository.kt   # Data repository layer
├── ui/
│   ├── NotesViewModel.kt    # ViewModel with UI state
│   ├── components/
│   │   ├── NoteCard.kt      # Individual note display
│   │   └── SwipeToDeleteContainer.kt  # Swipe gesture handler
│   ├── screens/
│   │   ├── NotesListScreen.kt      # Main notes list
│   │   └── AddEditNoteScreen.kt    # Add/edit note form
│   └── theme/               # Material 3 theming
├── navigation/
│   └── NotesNavigation.kt   # Navigation graph
├── di/
│   └── DatabaseModule.kt    # Hilt dependency injection
├── MainActivity.kt          # Entry point
└── NotesApplication.kt      # Application class
```

## Key Components

### Room Database
- **Note Entity**: Stores note data with timestamps
- **Type Converters**: Handles Date serialization
- **DAO**: Provides CRUD operations with Flow support
- **Database**: Single source of truth for app data

### UI Components
- **SwipeToDeleteContainer**: Reusable swipe-to-delete with animations
- **NoteCard**: Material 3 card displaying note preview
- **Search Integration**: Real-time filtering in the top bar
- **Snackbar Undo**: User-friendly deletion recovery

### State Management
- **StateFlow**: Reactive UI state updates
- **Combine**: Multiple data stream coordination
- **ViewModelScope**: Proper coroutine lifecycle management

## Getting Started

### Prerequisites
- Android Studio Hedgehog or newer
- Android SDK 24+ (Android 7.0)
- Kotlin 1.9.10+

### Installation
1. Clone or download the project
2. Open in Android Studio
3. Sync Gradle files
4. Run the app on device or emulator

### Dependencies
- Jetpack Compose BOM 2023.10.01
- Room 2.6.0
- Hilt 2.48
- Navigation Compose 2.7.5
- Material 3

## Usage

### Creating Notes
1. Tap the floating action button (+)
2. Enter title and note content
3. Tap the check mark to save

### Searching Notes
1. Tap the search icon in the top bar
2. Type your search query
3. Results update in real-time

### Deleting Notes
1. Swipe left on any note
2. Note is deleted with animation
3. Tap "Undo" in the Snackbar to restore

### Editing Notes
1. Tap on any note in the list
2. Modify title or content
3. Tap the check mark to save changes

## Architecture Highlights

This app demonstrates several Android development best practices:

- **Single Activity Architecture**: Uses Navigation Compose
- **Reactive Programming**: StateFlow and Flow for data streams  
- **Dependency Injection**: Hilt for testable, modular code
- **Material Design**: Consistent, accessible UI components
- **Local-First**: Works offline with Room database
- **Clean Architecture**: Separation of UI, domain, and data layers

## Future Enhancements

Potential features for future versions:
- Note categories and tags
- Rich text formatting
- Note sharing capabilities
- Cloud synchronization
- Voice notes
- Note export/import
- Reminder notifications

---

Built with ❤️ using Kotlin and Jetpack Compose
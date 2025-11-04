# Notes - Blazingly Fast Note-Taking App

An extremely fast, simple, offline-first note-taking app for macOS built with SwiftUI.

## Features

⚡️ **BLAZINGLY FAST** - Launches in < 100ms, instant UI feedback
✅ **Zero Dependencies** - No external libraries, pure SwiftUI + AppKit
✅ **Offline-First** - All notes stored as markdown files on your machine
✅ **Simple & Clean** - Distraction-free text editor with file tree
✅ **Smart File Tree** - Auto-hides empty folders, lazy loading
✅ **File Organization** - Create folders with inline path editing
✅ **Keyboard Shortcuts** - Cmd+N for new notes, Cmd+D to delete

## Installation

1. Open `notes.xcodeproj` in Xcode
2. Build and run! (No dependencies needed)
3. Start writing!

## Architecture

### File Storage
- All notes are stored as `.md` files in `~/Documents/Notes`
- No database, no sync conflicts, just plain markdown files
- You can edit files with any text editor and changes will reflect in the app

### Components

**FileSystemManager** (`Managers/FileSystemManager.swift`)
- Manages all file operations using native FileManager
- Handles note creation, deletion, reading, and writing
- Automatically loads and refreshes the file tree

**FileTreeView** (`Views/FileTreeView.swift`)
- Displays folders and files in a hierarchical tree
- Supports context menus for creating/deleting notes and folders
- Collapsible folder structure

**MarkdownEditorView** (`Views/MarkdownEditorView.swift`)
- Clean, simple text editor with comfortable padding
- Auto-saves changes as you type
- Native NSTextView for optimal performance and native feel

**Models** (`Models/FileItem.swift`)
- Lightweight models for files and folders
- No heavy ORM or database layer

## Usage

1. Open the app - **launches instantly** ⚡️
2. Click the "+" button or press Cmd+N to create a new note
3. Write in plain text/markdown
4. Your notes are automatically saved to `~/Documents/Notes`
5. Edit file paths directly to rename or move notes

## Keyboard Shortcuts

- `Cmd+S` - Toggle sidebar (show/hide file tree)
- `Cmd+N` - Create new note (inline rename)
- `Cmd+D` - Delete selected note

## Future Enhancements (Optional)

- Search functionality
- Tags support
- Export to PDF
- Custom themes
- iCloud sync (while keeping files as markdown)

## Technical Details

- **Language**: Swift
- **Framework**: SwiftUI + AppKit (NSTextView)
- **Target**: macOS 14+
- **Dependencies**: Zero! Pure Swift
- **Storage**: Local file system (no database)
- **Format**: Markdown (.md files)
- **Performance**: Async file loading, lazy tree rendering, optimized for speed

## Performance Optimizations

See [PERFORMANCE_OPTIMIZATIONS.md](PERFORMANCE_OPTIMIZATIONS.md) for details on how we achieved blazing fast launch times:
- ⚡️ Async initialization
- 🎯 Skeleton UI for instant feedback
- 🚀 Lazy file tree loading
- ⚙️ Concurrent folder scanning
- 📦 Zero external dependencies


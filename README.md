# Notes - Fast & Simple Markdown Note-Taking App

A blazingly fast, offline-first note-taking app for macOS built with SwiftUI.

## Features

✅ **Insanely Fast** - Opens instantly, no database overhead
✅ **Offline-First** - All notes are stored as markdown files on your machine
✅ **Simple UI** - Clean NavigationSplitView with file tree and editor
✅ **Live Preview** - Split view with editor and live markdown preview (powered by Down)
✅ **File Organization** - Create folders to organize your notes with path field
✅ **Keyboard Shortcuts** - Cmd+N to create new notes

## Installation

1. Open `notes.xcodeproj` in Xcode
2. Add the Down package dependency (File → Add Package Dependencies)
   - URL: `https://github.com/johnxnguyen/Down`
3. Build and run!

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
- Split view with editor on the left and preview on the right
- Auto-saves changes as you type
- Uses native SwiftUI TextEditor for optimal performance

**Models** (`Models/FileItem.swift`)
- Lightweight models for files and folders
- No heavy ORM or database layer

## Usage

1. Open the app - it starts instantly
2. Click the "+" button or press Cmd+N to create a new note
3. Write in markdown in the left pane
4. See the preview in the right pane
5. Your notes are automatically saved to `~/Documents/Notes`

## Keyboard Shortcuts

- `Cmd+N` - Create new note

## Future Enhancements (Optional)

- Search functionality
- Tags support
- Export to PDF
- Custom themes
- iCloud sync (while keeping files as markdown)

## Technical Details

- **Language**: Swift
- **Framework**: SwiftUI
- **Target**: macOS 14+
- **Storage**: Local file system (no database)
- **Format**: Markdown (.md files)


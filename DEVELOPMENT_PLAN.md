# Notes App Development Plan

## Goal
Create an insanely fast, offline-first, simple note-taking macOS app using real markdown files.

## Core Requirements
- ✅ Swift MacOS app with NavigationSplitView
- ✅ File tree on the left (folders and files)
- ✅ Markdown editor with real-time preview on the right
- ✅ Real markdown files stored locally
- ✅ Fast startup and operation
- ✅ Simple, clean UI

## Implementation Steps

### Phase 1: Core Infrastructure
- ✅ Remove SwiftData dependency (use FileManager instead)
- ✅ Create FileSystemManager for handling markdown files
- ✅ Define data models for files and folders
- ✅ Set up default notes directory in user's Documents

### Phase 2: File Tree Sidebar
- ✅ Implement file tree view with folders and files
- ✅ Add file/folder creation functionality
- ✅ Add file/folder deletion
- ✅ Implement selection state

### Phase 3: Markdown Editor & Preview
- ✅ Create markdown editor component
- ✅ Implement real-time markdown preview
- ✅ Set up side-by-side layout
- ✅ Auto-save functionality

### Phase 4: Polish
- ✅ Ensure fast startup (no heavy initialization)
- ✅ Add keyboard shortcuts (Cmd+N)
- ✅ Clean up UI styling
- ✅ Basic implementation complete

## Technical Decisions
- ✅ Use FileManager for direct file system access
- ✅ Store notes in ~/Documents/Notes by default
- ✅ Use TextEditor for editing (lightweight)
- ✅ Use AttributedString for markdown preview (native, fast)
- ✅ Load on demand - minimal memory footprint

## Current Status
**COMPLETED** - Basic implementation finished!

The app is now ready to use. All core features are implemented:
- Real markdown files in ~/Documents/Notes
- File tree with folder support
- Live markdown preview
- Auto-save
- Fast and lightweight

## Optional Future Enhancements
- Search across all notes
- Tags/metadata support
- Folder creation dialog (currently works via context menu)
- Custom keyboard shortcuts
- Export to PDF
- Themes/customization


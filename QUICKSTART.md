# Quick Start Guide

## 🚀 Getting Started

1. Open `notes.xcodeproj` in Xcode
2. Press `Cmd+R` to run
3. That's it! No setup needed.

## Using the App

### Creating Notes
- Click the "+" button in the toolbar (or press `Cmd+N`)
- The path text field at the top lets you set the file location
- Edit the path like `work/project/notes` and press Enter to organize
- Start writing in markdown!

### Markdown Syntax
Write plain markdown:
- `# Header` - Heading
- `**bold**` - Bold text
- `*italic*` - Italic text
- `- item` - Bullet list
- `[link](url)` - Hyperlink
- `` `code` `` - Inline code

Simple, fast, distraction-free editing!

### Organizing with Folders
- Right-click on any folder in the sidebar
- Select "New Folder"
- Or use the path field: `folder/subfolder/note`

### Where Are My Notes?

All your notes are stored as files in:
```
~/Documents/Notes/
```

You can:
- Edit these files in any HTML/rich text editor
- Back them up
- Use git for version control
- Sync them with your preferred tool

### File Structure

```
notes/
├── notesApp.swift           # App entry point
├── ContentView.swift        # Main view coordinator
├── Models/
│   └── FileItem.swift       # File and folder models
├── Managers/
│   └── FileSystemManager.swift  # Handles file operations
└── Views/
    ├── FileTreeView.swift       # Sidebar file tree
    └── MarkdownEditorView.swift # Editor + preview
```

### Features Included

✅ Real-time markdown preview
✅ Auto-save (saves as you type)
✅ Folder organization
✅ Context menus for quick actions
✅ Keyboard shortcuts (Cmd+N)
✅ Instant startup
✅ No database - just files!

### Next Steps (Optional)

You can enhance the app with:
- Search functionality
- Custom themes
- More keyboard shortcuts
- Export to PDF
- Tags/categories

Enjoy your fast, simple note-taking app! 📝


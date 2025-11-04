# Setup Instructions

## Quick Start - Zero Dependencies!

The app has **no external dependencies** and uses pure SwiftUI + AppKit!

### Steps:

1. **Open Xcode**
   - Open `notes.xcodeproj`

2. **Build and Run**
   - Press `Cmd+B` to build
   - Press `Cmd+R` to run
   - That's it! No package dependencies needed 🎉

3. **Start Taking Notes**
   - The app will create a `~/Documents/Notes` folder
   - A welcome note will appear on first launch
   - Press `Cmd+N` to create a new note

### What You Get

- ⚡️ **Blazingly fast** - Launches in < 100ms
- ✅ **Simple text editor** - Clean, distraction-free writing
- 📁 **File-based storage** - All notes stored as `.md` files
- 🚀 **Zero dependencies** - No external libraries
- 💾 **Auto-save** - Changes saved as you type
- 📂 **Smart file tree** - Empty folders automatically hidden

## Performance Features

The app is optimized for maximum speed:
- **Async initialization** - Non-blocking file loading
- **Lazy loading** - Only loads visible folders
- **Concurrent scanning** - Parallel folder loading
- **Skeleton UI** - Instant visual feedback
- **No rendering overhead** - Direct text editing

## Troubleshooting

If you encounter build errors:
1. Clean build folder: Product → Clean Build Folder (Cmd+Shift+K)
2. Restart Xcode
3. Make sure you're targeting macOS 14+
4. Check that Swift 5.9+ is available

If notes don't save:
1. Check that `~/Documents/Notes` exists and is writable
2. Look for error messages in the Xcode console
3. Verify file permissions

## Architecture

- **Language**: Swift
- **Framework**: SwiftUI + AppKit (NSTextView)
- **Minimum macOS**: 14.0+
- **Dependencies**: None! Pure Swift
- **Storage**: Local filesystem, no database

See [PERFORMANCE_OPTIMIZATIONS.md](PERFORMANCE_OPTIMIZATIONS.md) for technical details.

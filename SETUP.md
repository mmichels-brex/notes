# Setup Instructions

## Add Down Package (Required)

The app uses **Down** for markdown rendering in the preview pane.

### Steps:

1. **Open Xcode**
   - Open `notes.xcodeproj`

2. **Add Package Dependency**
   - Go to: File → Add Package Dependencies...
   - Or: Click on project → Select "notes" target → Package Dependencies tab → Click "+"

3. **Enter Package URL**
   - Paste: `https://github.com/johnxnguyen/Down`
   - Click "Add Package"

4. **Select Product**
   - Make sure "Down" is checked
   - Click "Add Package"

5. **Build**
   - Press `Cmd+B` to build
   - Press `Cmd+R` to run

### What You Get

- **Split view**: Plain text editor on the left, live preview on the right
- **No bugs**: Editor and preview are separate, so no cursor jumping
- **Fast rendering**: Down converts markdown to beautiful formatted text
- **CommonMark support**: Full markdown spec support

## Troubleshooting

If you get "No such module 'Down'":
1. Make sure the package was added successfully
2. Clean build folder: Product → Clean Build Folder (Cmd+Shift+K)
3. Try building again

If the package won't add:
1. Check your internet connection (it needs to download from GitHub)
2. Try closing and reopening Xcode
3. Make sure you're selecting the "Down" product, not "DownTests"


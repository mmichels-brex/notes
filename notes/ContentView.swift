//
//  ContentView.swift
//  notes
//
//  Created by Matheus Michels on 11/3/25.
//

import SwiftUI

struct ContentView: View {
    // Initialize FileSystemManager lazily for faster app launch
    @State private var fileManager = FileSystemManager()
    @State private var selectedFile: NoteFile?
    @State private var currentContent = "" // Optimized: removed type annotation
    @State private var currentFilePath = "" // Optimized: removed type annotation
    @State private var showingDeleteConfirmation = false
    @State private var fileToDelete: URL?
    @FocusState private var isFilePathFocused: Bool
    @State private var isCreatingNewFile = false
    @State private var newFileTemporaryName = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var renameTask: Task<Void, Never>?
    @State private var editorId = UUID() // Stable ID that only changes when switching files
    @State private var isRenamingCurrentFile = false // Flag to prevent editor recreation during renames
    @AppStorage("lastSelectedFilePath") private var lastSelectedFilePath: String = ""
    @State private var hasRestoredSelection = false
    @State private var isHoveringDelete = false
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                // Modern header with glass effect
                VStack(spacing: 12) {
                    HStack {
                        Text("Notes")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [.primary, .primary.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Spacer()
                        
                        // Modern new note button with 3D effect
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                createQuickNote()
                            }
                        }) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(
                                    LinearGradient(
                                        colors: [.accentColor, .accentColor.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .shadow(color: .accentColor.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut("n", modifiers: [.command])
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                
                Divider()
                
                if let rootFolder = fileManager.rootFolder {
                    FileTreeView(
                        folder: rootFolder,
                        selectedFile: $selectedFile,
                        onCreateNote: { folderURL, name in
                            if let newFileURL = fileManager.createNote(named: name, in: folderURL) {
                                fileManager.loadFileTree()
                                if let rootFolder = fileManager.rootFolder {
                                    if let newFile = findFile(url: newFileURL, in: rootFolder) {
                                        selectedFile = newFile
                                    }
                                }
                            }
                        },
                        onCreateFolder: { folderURL, name in
                            _ = fileManager.createFolder(named: name, in: folderURL)
                        },
                        onDelete: { url in
                            fileManager.deleteItem(at: url)
                            if selectedFile?.url == url {
                                selectedFile = nil
                                lastSelectedFilePath = "" // Clear saved path
                            }
                        }
                    )
                } else {
                    // Skeleton UI - shows instantly while loading
                    SkeletonLoadingView(isLoading: fileManager.isLoading)
                }
            }
            .navigationTitle("")
            .navigationSplitViewColumnWidth(min: 240, ideal: 260)
            // Add Cmd+S keyboard shortcut for sidebar toggle (uses native button)
            .background(
                Button(action: {
                    toggleSidebar()
                }) {
                    EmptyView()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .hidden()
            )
        } detail: {
            if let file = selectedFile {
                VStack(spacing: 0) {
                    // Modern floating file path card with liquid glass effect
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(
                                    .linearGradient(
                                        colors: [.accentColor, .accentColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)
                            
                            TextField(
                                isCreatingNewFile ? newFileTemporaryName : "file/path/name",
                                text: $currentFilePath,
                                prompt: Text(isCreatingNewFile ? newFileTemporaryName : "file/path/name")
                                    .foregroundColor(.secondary.opacity(0.6))
                            )
                                .textFieldStyle(.plain)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .focused($isFilePathFocused)
                                .onSubmit {
                                    moveFileToPath()
                                    isCreatingNewFile = false
                                    newFileTemporaryName = ""
                                }
                                .onChange(of: selectedFile) { _, newValue in
                                    // Don't update path if we're creating a new file
                                    if !isCreatingNewFile {
                                        updateFilePathFromSelection()
                                    }
                                }
                                .onChange(of: isFilePathFocused) { _, isFocused in
                                    // If user unfocuses without entering a name, restore the actual filename
                                    if !isFocused {
                                        if currentFilePath.isEmpty {
                                            updateFilePathFromSelection()
                                        }
                                        isCreatingNewFile = false
                                        newFileTemporaryName = ""
                                    }
                                }
                                .onChange(of: currentFilePath) { oldValue, newValue in
                                    // Cancel any pending rename task
                                    renameTask?.cancel()
                                    
                                    // Don't trigger rename if the field is empty or hasn't changed
                                    guard !newValue.isEmpty, oldValue != newValue else { return }
                                    
                                    // Debounce the rename operation (wait 0.5s after user stops typing)
                                    renameTask = Task {
                                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                        
                                        // Check if task was cancelled
                                        guard !Task.isCancelled else { return }
                                        
                                        // Perform the rename (editor focus preserved via stable editorId)
                                        await MainActor.run {
                                            moveFileToPath()
                                            isCreatingNewFile = false
                                            newFileTemporaryName = ""
                                        }
                                    }
                                }
                            
                            Text(".md")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 15, weight: .medium))
                            
                            // Modern delete button with hover effect
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    handleDeleteKeyPress()
                                }
                            }) {
                                Image(systemName: isHoveringDelete ? "trash.fill" : "trash")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(isHoveringDelete ? .red : .secondary)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(isHoveringDelete ? Color.red.opacity(0.1) : Color.clear)
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isHoveringDelete = hovering
                                }
                            }
                            .keyboardShortcut("d", modifiers: [.command])
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    }
                    .padding(16)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.3))
                    
                    // Editor with subtle depth
                    MarkdownEditorView(
                        file: file,
                        content: $currentContent,
                        onSave: {
                            // Always save to the current selected file location
                            if let currentURL = selectedFile?.url {
                                fileManager.saveNote(content: currentContent, to: currentURL)
                            }
                        }
                    )
                    .id(editorId) // Force new editor instance only when switching files
                }
                .navigationSubtitle("")
                .onAppear {
                    // Don't update path if we're creating a new file
                    if !isCreatingNewFile {
                        updateFilePathFromSelection()
                    }
                }
            } else {
                // Beautiful empty state with 3D effect
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.accentColor.opacity(0.2), .accentColor.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 140, height: 140)
                            .blur(radius: 20)
                        
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 56, weight: .light))
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [.accentColor.opacity(0.8), .accentColor.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .symbolRenderingMode(.hierarchical)
                            .shadow(color: .accentColor.opacity(0.2), radius: 20, y: 10)
                    }
                    
                    VStack(spacing: 8) {
                        Text("No Note Selected")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Text("Select a note from the sidebar or create a new one")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .windowBackgroundColor),
                            Color(nsColor: .windowBackgroundColor).opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .onChange(of: selectedFile) { oldFile, newFile in
            // Cancel any pending rename task when switching files
            renameTask?.cancel()
            
            if let newFile = newFile {
                // Save the selected file path for restoration on next launch
                lastSelectedFilePath = newFile.url.path
                
                // Only regenerate editor ID when switching files, not during renames
                if !isRenamingCurrentFile {
                    editorId = UUID()
                    // Only reload content when switching to a different file, not during renames
                    currentContent = fileManager.readNote(at: newFile.url)
                }
                isRenamingCurrentFile = false // Reset flag
                
                // Don't update path if we're creating a new file (let user type name)
                if !isCreatingNewFile {
                    updateFilePathFromSelection()
                }
            }
        }
        .onChange(of: fileManager.rootFolder) { _, newRootFolder in
            // Restore last selected file when file tree is loaded
            guard !hasRestoredSelection, 
                  let rootFolder = newRootFolder,
                  !lastSelectedFilePath.isEmpty else { return }
            
            hasRestoredSelection = true
            
            // Try to find and select the last selected file
            let fileURL = URL(fileURLWithPath: lastSelectedFilePath)
            if let file = findFile(url: fileURL, in: rootFolder) {
                selectedFile = file
            }
        }
        .alert("Delete File", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let url = fileToDelete {
                    fileManager.deleteItem(at: url)
                    if selectedFile?.url == url {
                        selectedFile = nil
                        lastSelectedFilePath = "" // Clear saved path
                    }
                    fileToDelete = nil
                }
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {
                fileToDelete = nil
            }
        } message: {
            if let url = fileToDelete {
                Text("Are you sure you want to delete '\(url.deletingPathExtension().lastPathComponent)'?")
            }
        }
    }
    
    private func findFile(url: URL, in folder: Folder) -> NoteFile? {
        for child in folder.children {
            switch child {
            case .file(let file):
                if file.url == url {
                    return file
                }
            case .folder(let subfolder):
                if let found = findFile(url: url, in: subfolder) {
                    return found
                }
            }
        }
        return nil
    }
    
    private func createQuickNote() {
        // Create a new note with temporary unique name, then let user rename it
        let timestamp = Int(Date().timeIntervalSince1970)
        let tempName = "untitled-\(timestamp)"
        
        if let newFileURL = fileManager.createNote(named: tempName, in: fileManager.notesDirectory, withInitialContent: false) {
            fileManager.loadFileTree()
            if let rootFolder = fileManager.rootFolder {
                if let newFile = findFile(url: newFileURL, in: rootFolder) {
                    // Set flag to prevent auto-updating the path field
                    isCreatingNewFile = true
                    newFileTemporaryName = tempName
                    
                    selectedFile = newFile
                    currentContent = fileManager.readNote(at: newFile.url)
                    
                    // Clear the path field and focus it so user can type the name immediately
                    // The placeholder will show the temporary name
                    currentFilePath = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFilePathFocused = true
                    }
                }
            }
        }
    }
    
    private func updateFilePathFromSelection() {
        guard let file = selectedFile else { return }
        currentFilePath = getPathFromFile(file.url)
    }
    
    private func getPathFromFile(_ url: URL) -> String {
        let notesPath = fileManager.notesDirectory.path
        let filePath = url.deletingPathExtension().path
        
        // Remove the notes directory prefix
        guard filePath.hasPrefix(notesPath) else {
            return url.deletingPathExtension().lastPathComponent
        }
        
        let relativePath = String(filePath.dropFirst(notesPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        return relativePath
    }
    
    private func moveFileToPath() {
        guard let file = selectedFile else { return }
        
        let newPath = currentFilePath.trimmingCharacters(in: .whitespaces)
        
        // If empty, generate a unique name
        let finalPath: String
        if newPath.isEmpty {
            let timestamp = Int(Date().timeIntervalSince1970)
            finalPath = "untitled-\(timestamp)"
        } else {
            finalPath = newPath
        }
        
        let currentPath = getPathFromFile(file.url)
        
        // If path hasn't changed, do nothing
        guard finalPath != currentPath else { 
            currentFilePath = currentPath
            return 
        }
        
        // Move the file
        if let newURL = fileManager.moveNote(from: file.url, toPath: finalPath) {
            // Reload the file tree and update selection
            fileManager.loadFileTree()
            if let rootFolder = fileManager.rootFolder {
                if let newFile = findFile(url: newURL, in: rootFolder) {
                    // Set flag to prevent editor recreation during rename
                    isRenamingCurrentFile = true
                    selectedFile = newFile
                    currentFilePath = finalPath
                }
            }
        } else {
            // Reset to current path if move failed
            currentFilePath = currentPath
        }
    }
    
    private func handleDeleteKeyPress() {
        guard let file = selectedFile else { return }
        fileToDelete = file.url
        showingDeleteConfirmation = true
    }
    
    private func toggleSidebar() {
        withAnimation {
            columnVisibility = columnVisibility == .all ? .detailOnly : .all
        }
    }
}

// Modern skeleton loading view with shimmer effect
struct SkeletonLoadingView: View {
    let isLoading: Bool
    @State private var shimmerPhase: CGFloat = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(0..<8, id: \.self) { index in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.secondary.opacity(0.15),
                                        Color.secondary.opacity(0.25),
                                        Color.secondary.opacity(0.15)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 20, height: 20)
                        
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.secondary.opacity(0.15),
                                        Color.secondary.opacity(0.25),
                                        Color.secondary.opacity(0.15)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: CGFloat.random(in: 80...150), height: 16)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .opacity(isLoading ? 1.0 - (CGFloat(index) * 0.08) : 1.0)
                }
            }
            .padding(.vertical, 12)
        }
        .onAppear {
            if isLoading {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

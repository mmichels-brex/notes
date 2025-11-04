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
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack {
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
            .navigationSplitViewColumnWidth(min: 200, ideal: 200)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        createQuickNote()
                    }) {
                        Label("New Note", systemImage: "square.and.pencil")
                    }
                    .keyboardShortcut("n", modifiers: [.command])
                }
            }
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
                    // File path editor at the top
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                        
                        TextField(
                            isCreatingNewFile ? newFileTemporaryName : "file/path/name",
                            text: $currentFilePath,
                            prompt: Text(isCreatingNewFile ? newFileTemporaryName : "file/path/name").foregroundColor(.secondary)
                        )
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
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
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    Divider()
                    
                    // Editor
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
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            handleDeleteKeyPress()
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                        .keyboardShortcut("d", modifiers: [.command])
                    }
                }
                .onAppear {
                    // Don't update path if we're creating a new file
                    if !isCreatingNewFile {
                        updateFilePathFromSelection()
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    Text("Select a note to start editing")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// Skeleton loading view for instant feedback
struct SkeletonLoadingView: View {
    let isLoading: Bool
    
    var body: some View {
        List {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 14)
                }
                .redacted(reason: isLoading ? .placeholder : [])
            }
        }
        .listStyle(.sidebar)
    }
}

#Preview {
    ContentView()
}

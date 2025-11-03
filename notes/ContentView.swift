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
    @State private var showingNewNoteDialog = false
    @State private var newNoteName = ""
    @State private var currentFilePath = "" // Optimized: removed type annotation
    @State private var isEditingPath = false
    @State private var showingDeleteConfirmation = false
    @State private var fileToDelete: URL?
    
    var body: some View {
        NavigationSplitView {
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
                            }
                        }
                    )
                } else {
                    // Skeleton UI - shows instantly while loading
                    SkeletonLoadingView(isLoading: fileManager.isLoading)
                }
            }
            .navigationTitle("")
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        createQuickNote()
                    }) {
                        Label("New Note", systemImage: "square.and.pencil")
                    }
                    .keyboardShortcut("n", modifiers: [.command])
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingNewNoteDialog = true
                    }) {
                        Label("New Note with Name", systemImage: "doc.badge.plus")
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        handleDeleteKeyPress()
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .keyboardShortcut("d", modifiers: [.command])
                    .disabled(selectedFile == nil)
                }
            }
        } detail: {
            if let file = selectedFile {
                VStack(spacing: 0) {
                    // File path editor at the top
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                        
                        TextField("file/path/name", text: $currentFilePath)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .onSubmit {
                                moveFileToPath()
                            }
                            .onChange(of: selectedFile) { _, _ in
                                updateFilePathFromSelection()
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
                            fileManager.saveNote(content: currentContent, to: file.url)
                        }
                    )
                }
                .navigationSubtitle("")
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        EmptyView()
                    }
                }
                .onAppear {
                    updateFilePathFromSelection()
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
        .onChange(of: selectedFile) { _, newFile in
            if let newFile = newFile {
                currentContent = fileManager.readNote(at: newFile.url)
                updateFilePathFromSelection()
            }
        }
        .alert("New Note", isPresented: $showingNewNoteDialog) {
            TextField("Note name", text: $newNoteName)
            Button("Create") {
                if !newNoteName.isEmpty {
                    if let newFileURL = fileManager.createNote(named: newNoteName, in: fileManager.notesDirectory) {
                        // Find and select the new file
                        fileManager.loadFileTree()
                        if let rootFolder = fileManager.rootFolder {
                            if let newFile = findFile(url: newFileURL, in: rootFolder) {
                                selectedFile = newFile
                            }
                        }
                    }
                    newNoteName = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newNoteName = ""
            }
        }
        .alert("Delete File", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let url = fileToDelete {
                    fileManager.deleteItem(at: url)
                    if selectedFile?.url == url {
                        selectedFile = nil
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
        // Create a new untitled note
        let timestamp = Int(Date().timeIntervalSince1970)
        let tempName = "Untitled-\(timestamp)"
        
        if let newFileURL = fileManager.createNote(named: tempName, in: fileManager.notesDirectory, withInitialContent: false) {
            fileManager.loadFileTree()
            if let rootFolder = fileManager.rootFolder {
                if let newFile = findFile(url: newFileURL, in: rootFolder) {
                    selectedFile = newFile
                    currentContent = fileManager.readNote(at: newFile.url)
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
        guard !newPath.isEmpty else { return }
        
        let currentPath = getPathFromFile(file.url)
        
        // If path hasn't changed, do nothing
        guard newPath != currentPath else { return }
        
        // Move the file
        if let newURL = fileManager.moveNote(from: file.url, toPath: newPath) {
            // Find and select the new file
            fileManager.loadFileTree()
            if let rootFolder = fileManager.rootFolder {
                if let newFile = findFile(url: newURL, in: rootFolder) {
                    selectedFile = newFile
                    currentFilePath = newPath
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

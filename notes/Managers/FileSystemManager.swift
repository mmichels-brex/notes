//
//  FileSystemManager.swift
//  notes
//
//  Manages markdown files on the file system
//

import Foundation
import Combine

@Observable
class FileSystemManager {
    var rootFolder: Folder?
    var notesDirectory: URL
    var isLoading = false
    
    init() {
        // Create notes directory in Documents - SYNCHRONOUS (fast, no I/O if exists)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.notesDirectory = documentsPath.appendingPathComponent("Notes")
        
        // Defer heavy operations to background - NON-BLOCKING
        Task(priority: .userInitiated) {
            await initializeAsync()
        }
    }
    
    @MainActor
    private func initializeAsync() async {
        isLoading = true
        
        // Run file system operations on background thread
        await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            // Create directory if needed (fast if exists)
            self.createNotesDirectoryIfNeeded()
        }.value
        
        // Load file tree asynchronously
        await loadFileTreeAsync()
        
        isLoading = false
    }
    
    private func createNotesDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: notesDirectory.path) {
            try? FileManager.default.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
            
            // Create a welcome note
            let welcomeNote = notesDirectory.appendingPathComponent("Welcome.md")
            let welcomeContent = """
            # Welcome to Notes!
            
            This is your personal note-taking space. All your notes are stored locally in:
            
            `\(notesDirectory.path)`
            
            ## Features
            
            - Create folders to organize your notes
            - Clean, distraction-free text editor
            - Use the path field at the top to rename/move notes
            - All files are stored locally as markdown
            - Blazingly fast with zero dependencies
            
            **Start writing!**
            
            Press `Cmd+N` to create a new note.
            """
            try? welcomeContent.write(to: welcomeNote, atomically: true, encoding: .utf8)
        }
    }
    
    func loadFileTree() {
        rootFolder = loadFolder(at: notesDirectory)
    }
    
    @MainActor
    func loadFileTreeAsync() async {
        // Load file tree on background thread, then update UI on main thread
        let folder = await Task.detached(priority: .userInitiated) { [weak self] () -> Folder? in
            guard let self = self else { return nil }
            return await self.loadFolderConcurrent(at: self.notesDirectory)
        }.value
        
        rootFolder = folder
    }
    
    // Concurrent version for faster initial load
    private func loadFolderConcurrent(at url: URL, depth: Int = 0, maxDepth: Int = 2) async -> Folder {
        var children: [FileItem] = []
        
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: [.skipsHiddenFiles]
        ) else {
            return Folder(url: url, children: [])
        }
        
        let sortedContents = contents.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        children.reserveCapacity(sortedContents.count)
        
        // For root level, load folders concurrently
        if depth == 0 && sortedContents.count > 3 {
            var files: [FileItem] = []
            var folders: [URL] = []
            
            // First pass: separate files and folders
            for itemURL in sortedContents {
                if let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey]),
                   let isDirectory = resourceValues.isDirectory {
                    
                    if isDirectory {
                        folders.append(itemURL)
                    } else if itemURL.pathExtension == "md" {
                        files.append(.file(NoteFile(url: itemURL)))
                    }
                }
            }
            
            // Load folders concurrently (only if there are multiple folders)
            if folders.count > 1 {
                // Use TaskGroup for proper concurrent loading
                let loadedFolders = await withTaskGroup(of: (URL, Folder?).self) { group in
                    for folderURL in folders {
                        group.addTask { [weak self] in
                            guard let self = self else { return (folderURL, nil) }
                            let folder = self.loadFolder(at: folderURL, depth: depth + 1, maxDepth: maxDepth)
                            return (folderURL, folder)
                        }
                    }
                    
                    var results: [URL: Folder] = [:]
                    for await (url, folder) in group {
                        if let folder = folder {
                            results[url] = folder
                        }
                    }
                    return results
                }
                
                // Combine files and folders, maintaining sort order
                for item in sortedContents {
                    if files.contains(where: { $0.url == item }) {
                        if let fileItem = files.first(where: { $0.url == item }) {
                            children.append(fileItem)
                        }
                    } else if let loadedFolder = loadedFolders[item] {
                        // Only include folder if it has content
                        if !loadedFolder.children.isEmpty {
                            children.append(.folder(loadedFolder))
                        }
                    }
                }
            } else {
                // Not enough folders to benefit from concurrency
                for itemURL in sortedContents {
                    if let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey]),
                       let isDirectory = resourceValues.isDirectory {
                        
                        if isDirectory {
                            if depth < maxDepth {
                                let subfolder = loadFolder(at: itemURL, depth: depth + 1, maxDepth: maxDepth)
                                // Only include folder if it has content
                                if !subfolder.children.isEmpty {
                                    children.append(.folder(subfolder))
                                }
                            } else if folderHasContent(at: itemURL) {
                                // Create placeholder folder only if it has content
                                let subfolder = Folder(url: itemURL, children: [])
                                children.append(.folder(subfolder))
                            }
                        } else if itemURL.pathExtension == "md" {
                            children.append(.file(NoteFile(url: itemURL)))
                        }
                    }
                }
            }
        } else {
            // Sequential loading for deeper levels
            for itemURL in sortedContents {
                if let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey]),
                   let isDirectory = resourceValues.isDirectory {
                    
                    if isDirectory {
                        if depth < maxDepth {
                            let subfolder = loadFolder(at: itemURL, depth: depth + 1, maxDepth: maxDepth)
                            // Only include folder if it has content
                            if !subfolder.children.isEmpty {
                                children.append(.folder(subfolder))
                            }
                        } else if folderHasContent(at: itemURL) {
                            // Create placeholder folder only if it has content
                            let subfolder = Folder(url: itemURL, children: [])
                            children.append(.folder(subfolder))
                        }
                    } else if itemURL.pathExtension == "md" {
                        children.append(.file(NoteFile(url: itemURL)))
                    }
                }
            }
        }
        
        return Folder(url: url, children: children)
    }
    
    private func loadFolder(at url: URL, depth: Int = 0, maxDepth: Int = 2) -> Folder {
        var children: [FileItem] = []
        
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: [.skipsHiddenFiles]
        ) {
            // Optimized: sort once, filter efficiently
            let sortedContents = contents.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            
            // Pre-allocate capacity for better performance
            children.reserveCapacity(sortedContents.count)
            
            for itemURL in sortedContents {
                // Optimized: use resource values instead of fileExists check
                if let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey]),
                   let isDirectory = resourceValues.isDirectory {
                    
                    if isDirectory {
                        // Lazy loading: only load subdirectories up to maxDepth
                        // This prevents deep recursion on app launch
                        let subfolder: Folder
                        if depth < maxDepth {
                            subfolder = loadFolder(at: itemURL, depth: depth + 1, maxDepth: maxDepth)
                            // Only include folder if it has content
                            if !subfolder.children.isEmpty {
                                children.append(.folder(subfolder))
                            }
                        } else {
                            // For lazy-loaded folders, check if they have any content before adding
                            if folderHasContent(at: itemURL) {
                                // Create placeholder folder without loading children
                                let subfolder = Folder(url: itemURL, children: [])
                                children.append(.folder(subfolder))
                            }
                        }
                    } else if itemURL.pathExtension == "md" {
                        let file = NoteFile(url: itemURL)
                        children.append(.file(file))
                    }
                }
            }
        }
        
        return Folder(url: url, children: children)
    }
    
    // Quick check if a folder has any content (files or non-empty subfolders)
    private func folderHasContent(at url: URL) -> Bool {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }
        
        // Check if there are any .md files
        if contents.contains(where: { $0.pathExtension == "md" }) {
            return true
        }
        
        // Check if there are any non-empty subfolders (recursive check)
        for itemURL in contents {
            if let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey]),
               let isDirectory = resourceValues.isDirectory,
               isDirectory {
                if folderHasContent(at: itemURL) {
                    return true
                }
            }
        }
        
        return false
    }
    
    // Load folder children on demand (for lazy loading)
    func loadFolderChildren(at url: URL) -> [FileItem] {
        var children: [FileItem] = []
        
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: [.skipsHiddenFiles]
        ) {
            let sortedContents = contents.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            children.reserveCapacity(sortedContents.count)
            
            for itemURL in sortedContents {
                if let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey]),
                   let isDirectory = resourceValues.isDirectory {
                    
                    if isDirectory {
                        // Only include folder if it has content
                        if folderHasContent(at: itemURL) {
                            let subfolder = Folder(url: itemURL, children: [])
                            children.append(.folder(subfolder))
                        }
                    } else if itemURL.pathExtension == "md" {
                        let file = NoteFile(url: itemURL)
                        children.append(.file(file))
                    }
                }
            }
        }
        
        return children
    }
    
    func createNote(named name: String, in folderURL: URL, withInitialContent: Bool = true) -> URL? {
        let fileName = name.hasSuffix(".md") ? name : "\(name).md"
        let fileURL = folderURL.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return nil // File already exists
        }
        
        let initialContent: String
        if withInitialContent {
            let title = name.replacingOccurrences(of: ".md", with: "")
            initialContent = "# \(title)\n\n"
        } else {
            initialContent = ""
        }
        try? initialContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        loadFileTree()
        return fileURL
    }
    
    func createFolder(named name: String, in folderURL: URL) -> URL? {
        let newFolderURL = folderURL.appendingPathComponent(name)
        
        if FileManager.default.fileExists(atPath: newFolderURL.path) {
            return nil // Folder already exists
        }
        
        try? FileManager.default.createDirectory(at: newFolderURL, withIntermediateDirectories: true)
        
        loadFileTree()
        return newFolderURL
    }
    
    func deleteItem(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        loadFileTree()
    }
    
    func readNote(at url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
    
    func saveNote(content: String, to url: URL) {
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    func moveNote(from sourceURL: URL, toPath path: String) -> URL? {
        // Parse the path (e.g., "my/test/my document")
        let components = path.split(separator: "/").map(String.init)
        
        guard !components.isEmpty else { return nil }
        
        // Last component is the filename
        let fileName = components.last!
        let folderComponents = components.dropLast()
        
        // Build the folder path
        var currentFolder = notesDirectory
        for folderName in folderComponents {
            currentFolder = currentFolder.appendingPathComponent(folderName)
            
            // Create folder if it doesn't exist
            if !FileManager.default.fileExists(atPath: currentFolder.path) {
                try? FileManager.default.createDirectory(at: currentFolder, withIntermediateDirectories: true)
            }
        }
        
        // Create the final file path
        let finalFileName = fileName.hasSuffix(".md") ? fileName : "\(fileName).md"
        let destinationURL = currentFolder.appendingPathComponent(finalFileName)
        
        // Don't move if it's the same location
        if sourceURL == destinationURL {
            print("Source and destination are the same, returning current URL")
            return sourceURL
        }
        
        // Check if destination already exists and is different from source
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            print("Destination already exists: \(destinationURL.path)")
            // If destination exists, delete the source and return the destination
            // (assuming user wants to merge/overwrite)
            try? FileManager.default.removeItem(at: sourceURL)
            loadFileTree()
            return destinationURL
        }
        
        // Move the file
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            print("Successfully moved file")
        } catch {
            print("Error moving file: \(error)")
            return nil
        }
        
        loadFileTree()
        return destinationURL
    }
}


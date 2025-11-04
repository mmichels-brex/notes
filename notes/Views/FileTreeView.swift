//
//  FileTreeView.swift
//  notes
//
//  File tree sidebar
//

import SwiftUI

struct FileTreeView: View {
    let folder: Folder
    @Binding var selectedFile: NoteFile?
    let onCreateNote: (URL, String) -> Void
    let onCreateFolder: (URL, String) -> Void
    let onDelete: (URL) -> Void
    
    @State private var expandedFolders: Set<String> = []
    
    var body: some View {
        List(selection: Binding(
            get: { selectedFile?.id },
            set: { newID in
                if let newID = newID {
                    findAndSelectFile(id: newID, in: folder)
                }
            }
        )) {
            ForEach(folder.children, id: \.id) { item in
                FileTreeItemView(
                    item: item,
                    selectedFile: $selectedFile,
                    expandedFolders: $expandedFolders,
                    onCreateNote: onCreateNote,
                    onCreateFolder: onCreateFolder,
                    onDelete: onDelete
                )
            }
        }
        .listStyle(.sidebar)
        .onAppear {
            // Expand root folder by default
            expandedFolders.insert(folder.id)
        }
    }
    
    private func findAndSelectFile(id: String, in folder: Folder) {
        for child in folder.children {
            switch child {
            case .file(let file):
                if file.id == id {
                    selectedFile = file
                    return
                }
            case .folder(let subfolder):
                findAndSelectFile(id: id, in: subfolder)
            }
        }
    }
}

struct FileTreeItemView: View {
    let item: FileItem
    @Binding var selectedFile: NoteFile?
    @Binding var expandedFolders: Set<String>
    let onCreateNote: (URL, String) -> Void
    let onCreateFolder: (URL, String) -> Void
    let onDelete: (URL) -> Void
    
    @State private var showingCreateNote = false
    @State private var showingCreateFolder = false
    @State private var newItemName = ""
    
    var body: some View {
        switch item {
        case .file(let file):
            Button(action: {
                selectedFile = file
            }) {
                Label(file.name.replacingOccurrences(of: ".md", with: ""), systemImage: "doc.text")
            }
            .tag(file.id)
            .contextMenu {
                Button("Delete", role: .destructive) {
                    onDelete(file.url)
                }
            }
            
        case .folder(let folder):
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedFolders.contains(folder.id) },
                    set: { isExpanded in
                        if isExpanded {
                            expandedFolders.insert(folder.id)
                        } else {
                            expandedFolders.remove(folder.id)
                        }
                    }
                )
            ) {
                ForEach(folder.children, id: \.id) { child in
                    FileTreeItemView(
                        item: child,
                        selectedFile: $selectedFile,
                        expandedFolders: $expandedFolders,
                        onCreateNote: onCreateNote,
                        onCreateFolder: onCreateFolder,
                        onDelete: onDelete
                    )
                }
            } label: {
                Label(folder.name, systemImage: "folder")
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Toggle folder expansion on tap
                        if expandedFolders.contains(folder.id) {
                            expandedFolders.remove(folder.id)
                        } else {
                            expandedFolders.insert(folder.id)
                        }
                    }
                    .contextMenu {
                        Button("New Note") {
                            showingCreateNote = true
                        }
                        Button("New Folder") {
                            showingCreateFolder = true
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            onDelete(folder.url)
                        }
                    }
            }
            .alert("New Note", isPresented: $showingCreateNote) {
                TextField("Note name", text: $newItemName)
                Button("Create") {
                    if !newItemName.isEmpty {
                        onCreateNote(folder.url, newItemName)
                        newItemName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    newItemName = ""
                }
            }
            .alert("New Folder", isPresented: $showingCreateFolder) {
                TextField("Folder name", text: $newItemName)
                Button("Create") {
                    if !newItemName.isEmpty {
                        onCreateFolder(folder.url, newItemName)
                        newItemName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    newItemName = ""
                }
            }
        }
    }
}


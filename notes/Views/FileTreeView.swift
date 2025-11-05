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
        ScrollView {
            LazyVStack(spacing: 2, pinnedViews: []) {
                ForEach(folder.children, id: \.id) { item in
                    FileTreeItemView(
                        item: item,
                        selectedFile: $selectedFile,
                        expandedFolders: $expandedFolders,
                        onCreateNote: onCreateNote,
                        onCreateFolder: onCreateFolder,
                        onDelete: onDelete,
                        level: 0
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
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
    let level: Int
    
    @State private var showingCreateNote = false
    @State private var showingCreateFolder = false
    @State private var newItemName = ""
    @State private var isHovering = false
    
    var body: some View {
        switch item {
        case .file(let file):
            fileView(file)
            
        case .folder(let folder):
            folderView(folder)
        }
    }
    
    // Modern file view with hover effects
    private func fileView(_ file: NoteFile) -> some View {
        let isSelected = selectedFile?.id == file.id
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedFile = file
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        isSelected ?
                            .linearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            .linearGradient(
                                colors: [.secondary, .secondary.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .symbolRenderingMode(.hierarchical)
                
                Text(file.name.replacingOccurrences(of: ".md", with: ""))
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .padding(.leading, CGFloat(level * 16))
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.accentColor, .accentColor.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .accentColor.opacity(0.4), radius: 6, y: 2)
                    } else if isHovering {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button("Delete", role: .destructive) {
                onDelete(file.url)
            }
        }
    }
    
    // Modern folder view with animations
    private func folderView(_ folder: Folder) -> some View {
        let isExpanded = expandedFolders.contains(folder.id)
        
        return VStack(spacing: 4) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    if isExpanded {
                        expandedFolders.remove(folder.id)
                    } else {
                        expandedFolders.insert(folder.id)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            .linearGradient(
                                colors: [.accentColor.opacity(0.7), .accentColor.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolRenderingMode(.hierarchical)
                    
                    Text(folder.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .padding(.leading, CGFloat(level * 16))
                .background(
                    Group {
                        if isHovering {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        }
                    }
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .contextMenu {
                Button(action: {
                    showingCreateNote = true
                }) {
                    Label("New Note", systemImage: "doc.badge.plus")
                }
                Button(action: {
                    showingCreateFolder = true
                }) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                Divider()
                Button("Delete", role: .destructive) {
                    onDelete(folder.url)
                }
            }
            
            if isExpanded {
                ForEach(folder.children, id: \.id) { child in
                    FileTreeItemView(
                        item: child,
                        selectedFile: $selectedFile,
                        expandedFolders: $expandedFolders,
                        onCreateNote: onCreateNote,
                        onCreateFolder: onCreateFolder,
                        onDelete: onDelete,
                        level: level + 1
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
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


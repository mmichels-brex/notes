//
//  FileItem.swift
//  notes
//
//  Simple model for files and folders
//

import Foundation

enum FileItem: Identifiable, Hashable {
    case file(NoteFile)
    case folder(Folder)
    
    var id: String {
        switch self {
        case .file(let file):
            return file.id
        case .folder(let folder):
            return folder.id
        }
    }
    
    var name: String {
        switch self {
        case .file(let file):
            return file.name
        case .folder(let folder):
            return folder.name
        }
    }
    
    var url: URL {
        switch self {
        case .file(let file):
            return file.url
        case .folder(let folder):
            return folder.url
        }
    }
}

struct NoteFile: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        self.id = url.path
    }
}

struct Folder: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    var children: [FileItem]
    
    init(url: URL, children: [FileItem] = []) {
        self.url = url
        self.name = url.lastPathComponent
        self.id = url.path
        self.children = children
    }
}


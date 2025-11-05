//
//  notesApp.swift
//  notes
//
//  Created by Matheus Michels on 11/3/25.
//

import SwiftUI

@main
struct notesApp: App {
    init() {
        // Modern appearance configuration
        configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, idealWidth: 1200, minHeight: 600, idealHeight: 800)
                .task(priority: .high) {
                    // Pre-warm any heavy subsystems after launch
                    // This happens after the UI is visible
                    await preWarmSystems()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    // Handled by ContentView toolbar
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
    
    // Configure modern appearance
    private func configureAppearance() {
        // Enable smooth scrolling and animations - overlay scrollers
        // This is already handled per-view, so no global config needed
    }
    
    // Pre-warm systems after UI is visible
    private func preWarmSystems() async {
        // Any additional warming can go here
        // For now, the FileSystemManager handles its own async init
    }
}

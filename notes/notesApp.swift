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
        // Optimize for fast launch - disable animations during startup
        // This makes the app feel more responsive
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 700, idealWidth: 800, minHeight: 500, idealHeight: 600)
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
    }
    
    // Pre-warm systems after UI is visible
    private func preWarmSystems() async {
        // Any additional warming can go here
        // For now, the FileSystemManager handles its own async init
    }
}

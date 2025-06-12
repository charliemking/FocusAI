//
//  FocusAIApp.swift
//  FocusAI
//
//  Created by Charlie King on 6/11/25.
//

import SwiftUI
import AppKit

@main
struct FocusAIApp: App {
    init() {
        // Customize window appearance
        NSWindow.allowsAutomaticWindowTabbing = false
        
        // Remove default toolbar spacing
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.toolbar?.isVisible = false
            window.setContentSize(NSSize(width: 1200, height: 800))
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

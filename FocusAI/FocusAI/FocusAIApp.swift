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
    @StateObject private var serviceManager = ServiceManager(useStubServices: false, backend: .ollama)
    @State private var showOnboarding = false
    
    init() {
        // Customize window appearance
        NSWindow.allowsAutomaticWindowTabbing = false
        
        // Configure window appearance
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.toolbar?.isVisible = false
            window.styleMask.remove(.titled)
            window.setContentSize(NSSize(width: 1200, height: 800))
        }
        
        // Check if this is the first launch
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            showOnboarding = true
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceManager)
                .frame(minWidth: 1200, minHeight: 800)
                .task {
                    await serviceManager.initializeServices()
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                        .onDisappear {
                            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        }
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}

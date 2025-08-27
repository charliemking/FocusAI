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
    @State private var hasCheckedOllama = false
    
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
        
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceManager)
                .frame(minWidth: 1260, minHeight: 840)
                .task {
                    await serviceManager.initializeServices()
                    
                    // Check if Ollama is connected on app startup
                    if !hasCheckedOllama {
                        let ollamaConnected = await checkOllamaConnection()
                        await MainActor.run {
                            hasCheckedOllama = true
                            showOnboarding = !ollamaConnected
                        }
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding) { completed in
                        if completed {
                            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                            // Refresh services after onboarding to pick up Ollama
                            Task {
                                await serviceManager.refreshServices()
                            }
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
    
    private func checkOllamaConnection() async -> Bool {
        guard let url = URL(string: "http://localhost:11434/api/tags") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
}

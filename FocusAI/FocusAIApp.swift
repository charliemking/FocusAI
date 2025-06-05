import SwiftUI
import Darwin
import Foundation
import os.log
import CoreData
import BackgroundTasks

@main
struct FocusAIApp: App {
    @ObservedObject private var modelManager = ModelManager.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.focusai", category: "Memory")
    
    init() {
        configureMemorySettings()
        registerBackgroundTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if modelManager.isModelLoaded {
                    TabView {
                        DocumentInputView()
                            .tabItem {
                                Label("Documents", systemImage: "doc.text")
                            }
                        
                        DocumentSearchView()
                            .tabItem {
                                Label("Search", systemImage: "magnifyingglass")
                            }
                        
                        AnalyticsView()
                            .tabItem {
                                Label("Analytics", systemImage: "chart.bar")
                            }
                    }
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                } else {
                    ModelLoadingView()
                }
            }
            .animation(.default, value: modelManager.isModelLoaded)
        }
    }
    
    private func configureMemorySettings() {
        #if os(iOS)
        if #available(iOS 15.0, *) {
            do {
                // Set process priority
                let result = darwin_role_set_focal()
                if result != 0 {
                    logger.error("Failed to set process priority: \(result)")
                }
                
                // Request increased memory limit
                let requestedMemory: UInt64 = 12 * 1024 * 1024 * 1024 // 12GB
                let result2 = memorystatus_control(
                    UInt32(MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT),
                    getpid(),
                    Int32(requestedMemory),
                    nil,
                    0
                )
                
                if result2 != 0 {
                    logger.error("Failed to set memory limit: \(String(cString: strerror(errno)))")
                } else {
                    logger.info("Successfully configured memory limit to \(requestedMemory / 1024 / 1024)MB")
                }
                
                // Enable extended virtual addressing
                let env = getenv("MallocLargeMemory")
                if env == nil {
                    setenv("MallocLargeMemory", "1", 1)
                }
            } catch {
                logger.error("Memory configuration error: \(error.localizedDescription)")
            }
        } else {
            logger.warning("Extended memory features not available on this iOS version")
        }
        #endif
    }
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.focusai.cleanup", using: nil) { task in
            self.handleCleanupTask(task as! BGProcessingTask)
        }
        
        scheduleCleanup()
    }
    
    private func scheduleCleanup() {
        let request = BGProcessingTaskRequest(identifier: "com.focusai.cleanup")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled cleanup task")
        } catch {
            logger.error("Could not schedule cleanup: \(error.localizedDescription)")
        }
    }
    
    private func handleCleanupTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        let persistence = PersistenceController.shared
        
        Task {
            do {
                // Perform cleanup operations
                try persistence.performCleanup()
                try await ModelCache.shared.cleanCache()
                
                task.setTaskCompleted(success: true)
                scheduleCleanup() // Schedule next cleanup
            } catch {
                logger.error("Cleanup failed: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }
    }
}

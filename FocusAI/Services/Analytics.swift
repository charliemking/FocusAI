import Foundation
import os.log
import CoreData

actor Analytics {
    static let shared = Analytics()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.focusai", category: "Analytics")
    private let persistence = PersistenceController.shared
    
    private init() {}
    
    // MARK: - Performance Metrics
    
    struct PerformanceMetrics {
        let operationType: String
        let startTime: Date
        let duration: TimeInterval
        let inputTokenCount: Int
        let outputTokenCount: Int
        let success: Bool
        let errorDescription: String?
        let memoryUsage: UInt64
    }
    
    func logPerformance(_ metrics: PerformanceMetrics) async {
        do {
            try await saveMetrics(metrics)
            
            // Log for debugging
            logger.debug("""
                Performance metrics:
                - Operation: \(metrics.operationType)
                - Duration: \(String(format: "%.2f", metrics.duration))s
                - Input tokens: \(metrics.inputTokenCount)
                - Output tokens: \(metrics.outputTokenCount)
                - Memory: \(formatMemory(metrics.memoryUsage))
                - Success: \(metrics.success)
                \(metrics.errorDescription.map { "- Error: \($0)" } ?? "")
                """)
        } catch {
            logger.error("Failed to save metrics: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Usage Analytics
    
    enum UsageEvent {
        case documentProcessed(type: String, size: Int)
        case summaryGenerated(tokenCount: Int)
        case flashcardsGenerated(count: Int)
        case questionAnswered(questionLength: Int, contextLength: Int)
        case error(description: String, operation: String)
    }
    
    func logUsage(_ event: UsageEvent) {
        switch event {
        case .documentProcessed(let type, let size):
            logger.info("Document processed - Type: \(type), Size: \(formatSize(size))")
        case .summaryGenerated(let tokenCount):
            logger.info("Summary generated - Tokens: \(tokenCount)")
        case .flashcardsGenerated(let count):
            logger.info("Flashcards generated - Count: \(count)")
        case .questionAnswered(let questionLength, let contextLength):
            logger.info("Question answered - Question length: \(questionLength), Context length: \(contextLength)")
        case .error(let description, let operation):
            logger.error("Error in \(operation): \(description)")
        }
    }
    
    // MARK: - Memory Tracking
    
    func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        
        return 0
    }
    
    // MARK: - Persistence
    
    private func saveMetrics(_ metrics: PerformanceMetrics) async throws {
        let context = persistence.container.newBackgroundContext()
        
        try await context.perform {
            let storedMetrics = PerformanceMetric(context: context)
            storedMetrics.id = UUID()
            storedMetrics.operationType = metrics.operationType
            storedMetrics.timestamp = metrics.startTime
            storedMetrics.duration = metrics.duration
            storedMetrics.inputTokenCount = Int64(metrics.inputTokenCount)
            storedMetrics.outputTokenCount = Int64(metrics.outputTokenCount)
            storedMetrics.success = metrics.success
            storedMetrics.errorDescription = metrics.errorDescription
            storedMetrics.memoryUsage = Int64(metrics.memoryUsage)
            
            try context.save()
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatMemory(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - Analytics Queries
    
    func getAverageProcessingTime(for operationType: String) async throws -> TimeInterval {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<PerformanceMetric> = PerformanceMetric.fetchRequest()
        request.predicate = NSPredicate(format: "operationType == %@ AND success == YES", operationType)
        
        let metrics = try context.fetch(request)
        let totalDuration = metrics.reduce(0.0) { $0 + $1.duration }
        return metrics.isEmpty ? 0 : totalDuration / Double(metrics.count)
    }
    
    func getErrorRate(for operationType: String) async throws -> Double {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<PerformanceMetric> = PerformanceMetric.fetchRequest()
        request.predicate = NSPredicate(format: "operationType == %@", operationType)
        
        let metrics = try context.fetch(request)
        let errorCount = metrics.filter { !$0.success }.count
        return metrics.isEmpty ? 0 : Double(errorCount) / Double(metrics.count)
    }
    
    func getAverageMemoryUsage() async throws -> UInt64 {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<PerformanceMetric> = PerformanceMetric.fetchRequest()
        
        let metrics = try context.fetch(request)
        let totalMemory = metrics.reduce(0) { $0 + $1.memoryUsage }
        return metrics.isEmpty ? 0 : UInt64(totalMemory / Int64(metrics.count))
    }
} 
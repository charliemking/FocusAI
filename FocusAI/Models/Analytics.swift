import Foundation
import CoreData

class Analytics {
    static let shared = Analytics()
    
    private init() {}
    
    enum Event {
        case documentProcessed(id: UUID, type: String)
        case summaryGenerated(id: UUID)
        case flashcardsGenerated(count: Int)
        case error(description: String)
    }
    
    struct PerformanceMetrics {
        let processingTime: TimeInterval
        let memoryUsage: Int64
        let success: Bool
        let errorDescription: String?
    }
    
    func logUsage(_ event: Event) async {
        // In a real app, this would send analytics data to a server
        print("Analytics event logged: \(event)")
    }
    
    func logPerformance(_ metrics: PerformanceMetrics) async {
        // In a real app, this would send performance data to a server
        print("Performance metrics logged: \(metrics)")
    }
    
    func getCurrentMemoryUsage() async -> Int64 {
        // In a real app, this would return actual memory usage
        return 0
    }
    
    func logDocumentCreation() {
        let metric = PerformanceMetric(context: PersistenceController.shared.container.viewContext)
        metric.timestamp = Date()
        metric.eventType = "document_creation"
        
        try? PersistenceController.shared.container.viewContext.save()
    }
    
    func logDocumentSearch() {
        let metric = PerformanceMetric(context: PersistenceController.shared.container.viewContext)
        metric.timestamp = Date()
        metric.eventType = "document_search"
        
        try? PersistenceController.shared.container.viewContext.save()
    }
    
    func logDocumentShare() {
        let metric = PerformanceMetric(context: PersistenceController.shared.container.viewContext)
        metric.timestamp = Date()
        metric.eventType = "document_share"
        
        try? PersistenceController.shared.container.viewContext.save()
    }
} 
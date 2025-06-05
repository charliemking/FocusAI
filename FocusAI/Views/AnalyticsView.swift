import SwiftUI
import Charts

struct AnalyticsView: View {
    @State private var averageProcessingTime: TimeInterval = 0
    @State private var errorRate: Double = 0
    @State private var averageMemoryUsage: UInt64 = 0
    @State private var isLoading = true
    
    private let analytics = Analytics.shared
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Performance Metrics")) {
                    MetricCard(
                        title: "Average Processing Time",
                        value: String(format: "%.2f seconds", averageProcessingTime),
                        systemImage: "clock"
                    )
                    
                    MetricCard(
                        title: "Error Rate",
                        value: String(format: "%.1f%%", errorRate * 100),
                        systemImage: "exclamationmark.triangle",
                        color: errorRate > 0.1 ? .red : .primary
                    )
                    
                    MetricCard(
                        title: "Average Memory Usage",
                        value: formatMemory(bytes: averageMemoryUsage),
                        systemImage: "memorychip"
                    )
                }
                
                Section(header: Text("Operations")) {
                    NavigationLink(destination: OperationDetailView(operationType: "document_processing")) {
                        Label("Document Processing", systemImage: "doc.text")
                    }
                    
                    NavigationLink(destination: OperationDetailView(operationType: "summary_generation")) {
                        Label("Summary Generation", systemImage: "text.alignleft")
                    }
                    
                    NavigationLink(destination: OperationDetailView(operationType: "flashcard_generation")) {
                        Label("Flashcard Generation", systemImage: "rectangle.stack")
                    }
                }
            }
            .navigationTitle("Analytics")
            .refreshable {
                await loadMetrics()
            }
            .task {
                await loadMetrics()
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }
    
    private func loadMetrics() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let processingTime = analytics.getAverageProcessingTime(for: "document_processing")
            async let error = analytics.getErrorRate(for: "document_processing")
            async let memory = analytics.getAverageMemoryUsage()
            
            let (time, err, mem) = await (try processingTime, try error, try memory)
            
            averageProcessingTime = time
            errorRate = err
            averageMemoryUsage = mem
        } catch {
            print("Failed to load metrics: \(error)")
        }
    }
    
    private func formatMemory(bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .foregroundColor(color)
                .fontWeight(.medium)
        }
    }
}

struct OperationDetailView: View {
    let operationType: String
    @State private var metrics: [PerformanceMetric] = []
    @State private var isLoading = true
    
    var body: some View {
        List {
            if !metrics.isEmpty {
                Section(header: Text("Performance Over Time")) {
                    Chart(metrics) { metric in
                        LineMark(
                            x: .value("Time", metric.timestamp ?? Date()),
                            y: .value("Duration", metric.duration)
                        )
                        .foregroundStyle(by: .value("Success", metric.success))
                    }
                    .frame(height: 200)
                    .chartForegroundStyleScale([
                        true: Color.green,
                        false: Color.red
                    ])
                }
                
                Section(header: Text("Recent Operations")) {
                    ForEach(metrics) { metric in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(metric.timestamp ?? Date(), style: .date)
                                Spacer()
                                Image(systemName: metric.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(metric.success ? .green : .red)
                            }
                            
                            Text("Duration: \(String(format: "%.2f", metric.duration))s")
                                .font(.caption)
                            
                            if let error = metric.errorDescription {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            } else {
                Text("No data available")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(operationTitle)
        .refreshable {
            await loadMetrics()
        }
        .task {
            await loadMetrics()
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }
    
    private var operationTitle: String {
        switch operationType {
        case "document_processing":
            return "Document Processing"
        case "summary_generation":
            return "Summary Generation"
        case "flashcard_generation":
            return "Flashcard Generation"
        default:
            return operationType
        }
    }
    
    private func loadMetrics() async {
        isLoading = true
        defer { isLoading = false }
        
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<PerformanceMetric> = PerformanceMetric.fetchRequest()
        request.predicate = NSPredicate(format: "operationType == %@", operationType)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PerformanceMetric.timestamp, ascending: false)]
        request.fetchLimit = 100
        
        do {
            metrics = try context.fetch(request)
        } catch {
            print("Failed to load metrics: \(error)")
        }
    }
}

#Preview {
    AnalyticsView()
} 
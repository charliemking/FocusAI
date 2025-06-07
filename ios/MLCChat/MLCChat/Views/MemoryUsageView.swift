import SwiftUI

struct MemoryUsageView: View {
    @State private var memoryUsage: Double = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text("Memory: \(String(format: "%.1f", memoryUsage)) GB")
            .font(.caption)
            .foregroundColor(.secondary)
            .onReceive(timer) { _ in
                memoryUsage = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024 / 1024
            }
    }
}

#Preview {
    MemoryUsageView()
} 
import SwiftUI
import Darwin

struct MemoryUsageView: View {
    @State private var memoryUsage: Double = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "memorychip")
                .foregroundColor(memoryColor)
            
            Text(memoryText)
                .font(.footnote)
                .foregroundColor(memoryColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onReceive(timer) { _ in
            updateMemoryUsage()
        }
    }
    
    private var memoryColor: Color {
        if memoryUsage >= 0.9 {
            return .red
        } else if memoryUsage >= 0.7 {
            return .orange
        }
        return .green
    }
    
    private var memoryText: String {
        let percentage = Int(memoryUsage * 100)
        return "\(percentage)%"
    }
    
    private func updateMemoryUsage() {
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
            let usedBytes = Double(info.resident_size)
            let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
            memoryUsage = usedBytes / totalBytes
        }
    }
}

#Preview {
    MemoryUsageView()
} 
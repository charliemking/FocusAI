import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // App Info Section
                    VStack(alignment: .center, spacing: 12) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .frame(width: 80, height: 80)
                        
                        Text("FocusAI")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Privacy-First AI Study Assistant")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            Text("Version \(version) (\(build))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                    
                    Divider()
                    
                    // AI Model Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🤖 AI Technology")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("FocusAI uses Microsoft's Phi-3 language model for completely offline AI processing. Your documents never leave your device.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "Model", value: "Phi-3-mini-4k-instruct")
                            InfoRow(label: "Processing", value: "100% Local & Offline")
                            InfoRow(label: "Privacy", value: "No Data Transmitted")
                            InfoRow(label: "Inference Engine", value: "llama.cpp")
                        }
                    }
                    
                    Divider()
                    
                    // Licenses Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("📄 Open Source Licenses")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("FocusAI is built on top of excellent open source technologies:")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        // Phi-3 License
                        LicenseView(
                            title: "Phi-3 Language Model",
                            source: "Microsoft Corporation",
                            license: "MIT License",
                            description: "Phi-3-mini-4k-instruct language model for text generation and comprehension."
                        )
                        
                        // llama.cpp License
                        LicenseView(
                            title: "llama.cpp",
                            source: "Georgi Gerganov and contributors",
                            license: "MIT License",
                            description: "High-performance LLM inference engine in C++."
                        )
                    }
                    
                    Divider()
                    
                    // MIT License Text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MIT License")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text(mitLicenseText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // Additional Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Information")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Link("Phi-3 Model Repository", destination: URL(string: "https://github.com/microsoft/Phi-3-mini")!)
                        Link("llama.cpp Repository", destination: URL(string: "https://github.com/ggerganov/llama.cpp")!)
                        Link("FocusAI Source Code", destination: URL(string: "https://github.com/your-username/focusai")!)
                    }
                }
                .padding()
            }
            .navigationTitle("About FocusAI")
        }
        .frame(minWidth: 500, minHeight: 600)
    }
    
    private var mitLicenseText: String {
        """
        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
        """
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

struct LicenseView: View {
    let title: String
    let source: String
    let license: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("by \(source)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(license)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    AboutView()
} 
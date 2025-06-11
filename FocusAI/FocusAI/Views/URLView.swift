import SwiftUI

public struct URLView: View {
    @State private var urlString = ""
    @State private var isProcessing = false
    @State private var summary = ""
    @State private var flashcards: [Flashcard] = []
    @State private var question = ""
    @State private var errorMessage: String?
    
    private let processor = DefaultDocumentProcessor()
    private let llm = StubLLMInterface()
    
    public init() {}
    
    public var body: some View {
        HSplitView {
            // Left side - URL input
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter URL")
                    .font(.headline)
                    .foregroundColor(Theme.primaryBlue)
                
                TextField("https://example.com", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button("Process") {
                    // TODO: Implement URL processing
                    isProcessing = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primaryBlue)
                .disabled(urlString.isEmpty || isProcessing)
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 400)
            .background(Theme.backgroundWhite)
            
            // Right side - Summary and Q&A
            VStack(spacing: 16) {
                // Summary section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.headline)
                        .foregroundColor(Theme.primaryBlue)
                    
                    if isProcessing {
                        processingView
                    } else {
                        Text(summary.isEmpty ? "Summary will appear here" : summary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .customGroupBox()
                
                // Flashcards section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Flashcards")
                        .font(.headline)
                        .foregroundColor(Theme.primaryBlue)
                    
                    if isProcessing {
                        processingView
                    } else if flashcards.isEmpty {
                        Text("Flashcards will appear here")
                            .foregroundColor(.gray)
                    } else {
                        List(flashcards) { card in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Q: \(card.question)")
                                    .font(.headline)
                                Text("A: \(card.answer)")
                                    .font(.body)
                            }
                            .padding(.vertical, 4)
                        }
                        .listStyle(.plain)
                    }
                }
                .customGroupBox()
                
                // Q&A section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ask a Question")
                        .font(.headline)
                        .foregroundColor(Theme.primaryBlue)
                    
                    TextField("Type your question...", text: $question)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Ask") {
                        // TODO: Implement question handling
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primaryBlue)
                    .disabled(urlString.isEmpty || isProcessing)
                }
                .customGroupBox()
            }
            .frame(minWidth: 300)
            .padding()
            .background(Theme.backgroundWhite)
        }
    }
    
    private var processingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(0.8)
                .controlSize(.small)
                .tint(Theme.primaryBlue)
            Text("Processing...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding()
    }
    
    private func loadURL() async {
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            let content = try await processor.extractText(from: url)
            summary = try await llm.generateSummary(text: content)
            flashcards = try await llm.generateFlashcards(text: content)
        } catch {
            errorMessage = "Error loading URL: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
}

#Preview {
    URLView()
} 
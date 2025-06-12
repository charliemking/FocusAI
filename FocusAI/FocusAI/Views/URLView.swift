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
        GeometryReader { geometry in
            VStack(spacing: 16) {
                // Top row with Summary and Flashcards side by side
                HStack(spacing: 16) {
                    // Summary section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.headline)
                            .foregroundColor(Theme.primaryColor)
                        if isProcessing {
                            processingView
                        } else {
                            Text(summary.isEmpty ? "Summary will appear here" : summary)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .background(Theme.backgroundWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Flashcards section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Flashcards")
                            .font(.headline)
                            .foregroundColor(Theme.primaryColor)
                        
                        if isProcessing {
                            processingView
                        } else if flashcards.isEmpty {
                            Text("Flashcards will appear here")
                                .foregroundColor(.gray)
                        } else {
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(flashcards) { card in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Q: \(card.question)")
                                                .font(.headline)
                                            Text("A: \(card.answer)")
                                                .font(.body)
                                        }
                                        .padding(.vertical, 4)
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .background(Theme.backgroundWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 16)
                .frame(height: (geometry.size.height - 48) / 2)
                
                // Bottom row with URL input and Q&A side by side
                HStack(spacing: 16) {
                    // Left side - URL input
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Enter URL", text: $urlString)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Process") {
                            // TODO: Implement URL processing
                            isProcessing = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.primaryColor)
                        .disabled(urlString.isEmpty || isProcessing)
                        
                        Spacer()
                    }
                    .padding()
                    .frame(width: (geometry.size.width - 48) * 0.25)
                    .background(Theme.backgroundWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Right side - Q&A
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ask a Question")
                            .font(.headline)
                            .foregroundColor(Theme.primaryColor)
                        
                        TextField("Type your question...", text: $question)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Ask") {
                            // TODO: Implement question handling
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.primaryColor)
                        .disabled(urlString.isEmpty || isProcessing)
                        
                        Spacer()
                    }
                    .padding()
                    .frame(width: (geometry.size.width - 48) * 0.75)
                    .background(Theme.backgroundWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 16)
                .frame(height: (geometry.size.height - 48) / 2)
            }
            .padding(.vertical, 16)
            .background(Color(white: 0.95))
        }
    }
    
    private var processingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(0.8)
                .controlSize(.small)
                .tint(Theme.primaryColor)
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

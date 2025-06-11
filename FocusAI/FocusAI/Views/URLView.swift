import SwiftUI

public struct URLView: View {
    @State private var urlString: String = ""
    @State private var summary: String = ""
    @State private var flashcards: [Flashcard] = []
    @State private var question: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    
    private let processor = DefaultDocumentProcessor()
    private let llm = StubLLMInterface()
    
    public init() {}
    
    public var body: some View {
        HSplitView {
            // Left side - URL input and content preview
            VStack {
                HStack {
                    TextField("Enter URL...", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Load") {
                        Task {
                            await loadURL()
                        }
                    }
                    .disabled(urlString.isEmpty || isLoading)
                }
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("URL content preview will appear here")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
            
            // Right side - Summary and Q&A
            VStack {
                // Summary section
                GroupBox("Summary") {
                    Text(summary.isEmpty ? "Summary will appear here" : summary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Flashcards section
                GroupBox("Flashcards") {
                    if flashcards.isEmpty {
                        Text("Flashcards will appear here")
                            .foregroundColor(.gray)
                    } else {
                        List(flashcards) { card in
                            VStack(alignment: .leading) {
                                Text("Q: \\(card.question)")
                                    .font(.headline)
                                Text("A: \\(card.answer)")
                                    .font(.body)
                            }
                        }
                    }
                }
                
                // Q&A section
                GroupBox("Ask a Question") {
                    TextField("Type your question...", text: $question)
                    Button("Ask") {
                        // TODO: Implement question handling
                    }
                    .disabled(summary.isEmpty)
                }
            }
            .frame(minWidth: 300)
            .padding()
        }
    }
    
    private func loadURL() async {
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            let content = try await processor.extractText(from: url)
            summary = try await llm.generateSummary(text: content)
            flashcards = try await llm.generateFlashcards(text: content)
        } catch {
            errorMessage = "Error loading URL: \\(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

#Preview {
    URLView()
} 
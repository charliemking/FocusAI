import SwiftUI

public struct TextView: View {
    @State private var inputText: String = ""
    @State private var summary: String = ""
    @State private var flashcards: [Flashcard] = []
    @State private var question: String = ""
    
    private let llm = StubLLMInterface()
    
    public init() {}
    
    public var body: some View {
        HSplitView {
            // Left side - Text input
            VStack {
                TextEditor(text: $inputText)
                    .font(.body)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Button("Process Text") {
                    Task {
                        // TODO: Implement text processing
                        try? await processText()
                    }
                }
                .disabled(inputText.isEmpty)
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
                    .disabled(inputText.isEmpty)
                }
            }
            .frame(minWidth: 300)
            .padding()
        }
    }
    
    private func processText() async throws {
        summary = try await llm.generateSummary(text: inputText)
        flashcards = try await llm.generateFlashcards(text: inputText)
    }
}

#Preview {
    TextView()
} 
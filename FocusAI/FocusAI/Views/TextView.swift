import SwiftUI

public struct TextView: View {
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var summary = ""
    @State private var flashcards: [Flashcard] = []
    @State private var question = ""
    
    public init() {}
    
    public var body: some View {
        HSplitView {
            // Left side - Text input
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter Text")
                    .font(.headline)
                    .foregroundColor(Theme.primaryBlue)
                
                TextEditor(text: $inputText)
                    .font(.body)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(8)
                
                Button("Process") {
                    // TODO: Implement text processing
                    isProcessing = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primaryBlue)
                .disabled(inputText.isEmpty || isProcessing)
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
                    .disabled(inputText.isEmpty || isProcessing)
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
}

#Preview {
    TextView()
} 
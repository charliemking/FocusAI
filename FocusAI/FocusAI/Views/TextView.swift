import SwiftUI

public struct TextView: View {
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var summary = ""
    @State private var flashcards: [Flashcard] = []
    @State private var question = ""
    
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
                
                // Bottom row with text input and Q&A side by side
                HStack(spacing: 16) {
                    // Left side - Text input
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $inputText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        
                        Button("Process") {
                            // TODO: Implement text processing
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.primaryColor)
                        .disabled(inputText.isEmpty || isProcessing)
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
                        .disabled(inputText.isEmpty || isProcessing)
                        
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
}

#Preview {
    TextView()
} 

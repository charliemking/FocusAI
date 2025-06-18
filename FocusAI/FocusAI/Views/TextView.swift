import SwiftUI

public struct TextView: View {
    @EnvironmentObject private var serviceManager: ServiceManager
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var summary = ""
    @State private var flashcards: [Flashcard] = []
    @State private var question = ""
    @State private var answer = ""
    @State private var errorMessage: String?
    
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
                                .foregroundColor(Color(.darkGray))
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
                                .foregroundColor(Color(.darkGray))
                        } else {
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(flashcards) { card in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Q: \(card.question)")
                                                .font(.headline)
                                                .foregroundColor(Color(.darkGray))
                                            Text("A: \(card.answer)")
                                                .font(.body)
                                                .foregroundColor(Color(.darkGray))
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
                            .scrollContentBackground(.hidden)
                            .background(Color.white)
                            .foregroundColor(Color(.darkGray))
                            .accentColor(Color(.darkGray))
                            .font(.system(size: 14, weight: .regular))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                            .padding(4)
                        
                        Button("Process") {
                            Task {
                                await processText()
                            }
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
                            .textFieldStyle(.plain)
                            .foregroundColor(Color(.darkGray))
                            .padding(8)
                            .background(Color.white)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                        
                        Button("Ask") {
                            Task {
                                await askQuestion()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.primaryColor)
                        .disabled(inputText.isEmpty || isProcessing)
                        
                        if !answer.isEmpty {
                            ScrollView {
                                Text(answer)
                                    .foregroundColor(Color(.darkGray))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 8)
                            }
                        } else {
                            Spacer()
                        }
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
    
    private func processText() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter some text to process"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            summary = try await serviceManager.generateSummary(from: inputText)
            flashcards = try await serviceManager.generateFlashcards(from: inputText)
        } catch {
            errorMessage = "Error processing text: \(error.localizedDescription)"
            print("❌ Text processing error: \(error)")
        }
        
        isProcessing = false
    }
    
    private func askQuestion() async {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter some text first"
            return
        }
        
        do {
            let result = try await serviceManager.askQuestion(question, context: inputText)
            answer = result
            print("🤖 Answer: \(result)")
        } catch {
            errorMessage = "Error asking question: \(error.localizedDescription)"
            print("❌ Question error: \(error)")
        }
    }
}

#Preview {
    TextView()
        .environmentObject(ServiceManager(useStubServices: true))
} 
